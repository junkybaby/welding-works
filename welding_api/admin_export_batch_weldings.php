<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$admin = require_admin();
$batchId = intval($_GET["batch_id"] ?? 0);

if ($batchId <= 0) {
  http_response_code(400);
  respond("error", "Batch id is required.");
}

function sanitize_zip_segment($value) {
  $clean = preg_replace('/[^A-Za-z0-9._ -]/', '_', (string)$value);
  $clean = trim((string)$clean);
  return $clean !== "" ? $clean : "item";
}

function relative_upload_to_absolute($relativePath) {
  $relativePath = trim((string)$relativePath);
  if ($relativePath === "") return "";
  $clean = ltrim(str_replace(["\\", "/"], DIRECTORY_SEPARATOR, $relativePath), "\\/");
  return __DIR__ . DIRECTORY_SEPARATOR . $clean;
}

function extract_demo_timestamp($path) {
  if (preg_match('/(?:demo_\d+_|run_)(\d+)/', (string)$path, $matches)) {
    return $matches[1];
  }
  return "";
}

function find_latest_original_for_trainee($batchTraineeId) {
  $pattern = __DIR__ . DIRECTORY_SEPARATOR . "yolo_uploads" . DIRECTORY_SEPARATOR . "demo_" . intval($batchTraineeId) . "_*.*";
  $matches = glob($pattern) ?: [];
  if (!$matches) {
    return "";
  }

  usort($matches, function ($a, $b) {
    return filemtime($b) <=> filemtime($a);
  });

  foreach ($matches as $match) {
    if (is_file($match)) {
      return $match;
    }
  }

  return "";
}

function find_annotated_for_timestamp($timestamp) {
  $timestamp = trim((string)$timestamp);
  if ($timestamp === "") {
    return "";
  }

  $candidate =
    __DIR__
    . DIRECTORY_SEPARATOR . "yolo_outputs"
    . DIRECTORY_SEPARATOR . "run_" . $timestamp
    . DIRECTORY_SEPARATOR . "annotated.png";

  return is_file($candidate) ? $candidate : "";
}

function resolve_export_file($relativePath, $batchTraineeId, $type) {
  $resolved = [
    "path" => "",
    "source" => "missing",
    "missing_path" => trim((string)$relativePath),
  ];

  $absolutePath = relative_upload_to_absolute($relativePath);
  if ($absolutePath !== "" && is_file($absolutePath)) {
    $resolved["path"] = $absolutePath;
    $resolved["source"] = "stored_path";
    return $resolved;
  }

  $latestOriginal = find_latest_original_for_trainee($batchTraineeId);
  if ($latestOriginal === "") {
    return $resolved;
  }

  if ($type === "original") {
    $resolved["path"] = $latestOriginal;
    $resolved["source"] = "latest_original_fallback";
    return $resolved;
  }

  $timestamps = array_values(array_unique(array_filter([
    extract_demo_timestamp($relativePath),
    extract_demo_timestamp($latestOriginal),
  ])));

  foreach ($timestamps as $timestamp) {
    $annotated = find_annotated_for_timestamp($timestamp);
    if ($annotated !== "") {
      $resolved["path"] = $annotated;
      $resolved["source"] = "latest_annotated_fallback";
      return $resolved;
    }
  }

  return $resolved;
}

function convert_image_to_jpg_temp($sourcePath) {
  if (!is_file($sourcePath) || !function_exists("imagecreatefromstring") || !function_exists("imagejpeg")) {
    return "";
  }

  $contents = @file_get_contents($sourcePath);
  if ($contents === false) {
    return "";
  }

  $image = @imagecreatefromstring($contents);
  if (!$image) {
    return "";
  }

  $width = imagesx($image);
  $height = imagesy($image);
  $canvas = imagecreatetruecolor($width, $height);
  if (!$canvas) {
    imagedestroy($image);
    return "";
  }

  $white = imagecolorallocate($canvas, 255, 255, 255);
  imagefill($canvas, 0, 0, $white);
  imagecopy($canvas, $image, 0, 0, 0, 0, $width, $height);

  $tempPath = sys_get_temp_dir() . DIRECTORY_SEPARATOR . uniqid("batch_export_img_", true) . ".jpg";
  $saved = @imagejpeg($canvas, $tempPath, 90);

  imagedestroy($canvas);
  imagedestroy($image);

  return $saved && is_file($tempPath) ? $tempPath : "";
}

function prepare_export_source($absolutePath, &$tempFiles) {
  $extension = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));
  if ($extension === "jpg" || $extension === "jpeg") {
    return [
      "source" => $absolutePath,
      "extension" => "jpg",
      "converted" => false,
    ];
  }

  $convertedPath = convert_image_to_jpg_temp($absolutePath);
  if ($convertedPath !== "") {
    $tempFiles[] = $convertedPath;
    return [
      "source" => $convertedPath,
      "extension" => "jpg",
      "converted" => true,
    ];
  }

  return [
    "source" => $absolutePath,
    "extension" => $extension !== "" ? $extension : "img",
    "converted" => false,
  ];
}

function recursive_remove_directory($path) {
  if (!is_dir($path)) {
    return;
  }

  $items = scandir($path);
  if ($items === false) {
    return;
  }

  foreach ($items as $item) {
    if ($item === "." || $item === "..") {
      continue;
    }

    $itemPath = $path . DIRECTORY_SEPARATOR . $item;
    if (is_dir($itemPath)) {
      recursive_remove_directory($itemPath);
      continue;
    }

    @unlink($itemPath);
  }

  @rmdir($path);
}

function powershell_single_quote($value) {
  return str_replace("'", "''", (string)$value);
}

function create_zip_with_powershell($tempZipPath, $filesToAdd, $manifestContents) {
  if (PHP_OS_FAMILY !== "Windows" || !function_exists("shell_exec")) {
    return false;
  }

  $powershellPath = getenv("SystemRoot")
    ? getenv("SystemRoot") . "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    : "powershell.exe";

  $stageDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . uniqid("batch_welding_export_stage_", true);
  if (!@mkdir($stageDir, 0777, true) && !is_dir($stageDir)) {
    return false;
  }

  try {
    foreach ($filesToAdd as $file) {
      $targetPath = $stageDir . DIRECTORY_SEPARATOR . str_replace(["\\", "/"], DIRECTORY_SEPARATOR, $file["target"]);
      $targetDir = dirname($targetPath);
      if (!is_dir($targetDir) && !@mkdir($targetDir, 0777, true) && !is_dir($targetDir)) {
        throw new RuntimeException("Unable to prepare export directory.");
      }

      if (!@copy($file["source"], $targetPath)) {
        throw new RuntimeException("Unable to stage export file.");
      }
    }

    if (@file_put_contents($stageDir . DIRECTORY_SEPARATOR . "manifest.txt", $manifestContents) === false) {
      throw new RuntimeException("Unable to prepare export manifest.");
    }

    $psStageDir = powershell_single_quote($stageDir);
    $psTempZipPath = powershell_single_quote($tempZipPath);
    $script =
      "Add-Type -AssemblyName 'System.IO.Compression.FileSystem'; " .
      "if (Test-Path -LiteralPath '$psTempZipPath') { Remove-Item -LiteralPath '$psTempZipPath' -Force; } " .
      "[System.IO.Compression.ZipFile]::CreateFromDirectory('$psStageDir', '$psTempZipPath')";

    $command =
      '"' . $powershellPath . '"' .
      " -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command " .
      escapeshellarg($script) .
      " 2>&1";

    $output = shell_exec($command);
    if (!is_file($tempZipPath) || filesize($tempZipPath) === 0) {
      throw new RuntimeException("ZIP creation fallback failed." . ($output ? " " . trim((string)$output) : ""));
    }

    return true;
  } finally {
    recursive_remove_directory($stageDir);
  }
}

try {
  $pdo = db();
  $batchStmt = $pdo->prepare("
    SELECT id, name, status, trainer_email, trainer_username, created_at
    FROM batches
    WHERE id = ?
    LIMIT 1
  ");
  $batchStmt->execute([$batchId]);
  $batch = $batchStmt->fetch(PDO::FETCH_ASSOC);

  if (!$batch) {
    http_response_code(404);
    respond("error", "Batch not found.");
  }

  $traineeStmt = $pdo->prepare("
    SELECT
      bt.id,
      bt.trainee_name,
      bt.training_center,
      bt.status,
      bt.result,
      tp.demo_image_url,
      tp.demo_annotated_image_url,
      tp.demo_status,
      tp.demo_date_completed
    FROM batch_trainees bt
    LEFT JOIN trainee_progress tp ON tp.batch_trainee_id = bt.id
    WHERE bt.batch_id = ?
    ORDER BY bt.id ASC
  ");
  $traineeStmt->execute([$batchId]);
  $trainees = $traineeStmt->fetchAll(PDO::FETCH_ASSOC);

  $safeBatchName = sanitize_zip_segment($batch["name"] ?? "batch");
  $zipFileName = "batch_" . sanitize_zip_segment($batch["id"]) . "_" . $safeBatchName . "_welding_outputs.zip";
  $tempZipPath = sys_get_temp_dir() . DIRECTORY_SEPARATOR . uniqid("batch_welding_export_", true) . ".zip";
  $filesToAdd = [];
  $tempFilesToCleanup = [];

  $manifestLines = [
    "Batch: " . ($batch["name"] ?? "-"),
    "Batch ID: " . ($batch["id"] ?? "-"),
    "Trainer Email: " . ($batch["trainer_email"] ?? "-"),
    "Trainer Username: " . ($batch["trainer_username"] ?? "-"),
    "Status: " . ($batch["status"] ?? "-"),
    "Created At: " . ($batch["created_at"] ?? "-"),
    "",
    "Files:",
  ];

  foreach ($trainees as $index => $trainee) {
    $safeTraineeName = sanitize_zip_segment($trainee["trainee_name"] ?? ("trainee_" . ($index + 1)));
    $folderName = sprintf(
      "%02d_%s",
      $index + 1,
      $safeTraineeName
    );

    $files = [
      "original" => $trainee["demo_image_url"] ?? "",
      "annotated" => $trainee["demo_annotated_image_url"] ?? "",
    ];

    $manifestLines[] =
      ($trainee["trainee_name"] ?? "-")
      . " | Result: " . ($trainee["result"] ?? "-")
      . " | Demo Status: " . ($trainee["demo_status"] ?? "-")
      . " | Demo Date: " . ($trainee["demo_date_completed"] ?? "-");

    foreach ($files as $type => $relativePath) {
      $resolvedFile = resolve_export_file($relativePath, $trainee["id"] ?? 0, $type);
      $absolutePath = $resolvedFile["path"];
      if ($absolutePath === "") {
        $manifestLines[] =
          "  - missing " . $type . " image"
          . ($resolvedFile["missing_path"] !== "" ? " (stored path: " . $resolvedFile["missing_path"] . ")" : "");
        continue;
      }

      $preparedFile = prepare_export_source($absolutePath, $tempFilesToCleanup);
      $fileBaseName = $safeTraineeName . "_" . $type;
      $targetName = $folderName . DIRECTORY_SEPARATOR . $fileBaseName . "." . $preparedFile["extension"];
      $filesToAdd[] = [
        "source" => $preparedFile["source"],
        "target" => $targetName,
      ];
      $note = $resolvedFile["source"] === "stored_path" ? "" : " [recovered from latest available file]";
      if ($preparedFile["converted"]) {
        $note .= " [exported as jpg]";
      }
      $manifestLines[] = "  - " . $targetName . $note;
    }

    $manifestLines[] = "";
  }

  $manifestContents = implode(PHP_EOL, $manifestLines);
  if (class_exists("ZipArchive")) {
    $zip = new ZipArchive();
    if ($zip->open($tempZipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
      http_response_code(500);
      respond("error", "Unable to create ZIP file.");
    }

    foreach ($filesToAdd as $file) {
      $zip->addFile($file["source"], $file["target"]);
    }

    $zip->addFromString("manifest.txt", $manifestContents);
    $zip->close();
  } elseif (!create_zip_with_powershell($tempZipPath, $filesToAdd, $manifestContents)) {
    http_response_code(500);
    respond("error", "ZIP export is not available on this PHP installation.");
  }

  audit_log("admin_exported_batch_weldings", $admin["email"], $admin["role"], "batch", $batchId, [
    "batch_name" => $batch["name"] ?? "",
    "zip_name" => $zipFileName,
    "trainee_count" => count($trainees),
  ], $admin["user_id"]);

  header("Content-Type: application/zip");
  header("Content-Disposition: attachment; filename=\"" . $zipFileName . "\"");
  header("Content-Length: " . filesize($tempZipPath));
  header("Cache-Control: no-store, no-cache, must-revalidate");
  header("Pragma: no-cache");
  foreach ($tempFilesToCleanup as $tempFile) {
    @unlink($tempFile);
  }
  readfile($tempZipPath);
  @unlink($tempZipPath);
  exit;
} catch (Throwable $e) {
  http_response_code(500);
  respond("error", "Server error: " . $e->getMessage());
}
