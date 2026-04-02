<?php
require_once __DIR__ . "/db.php";

function ensure_directory($path) {
  if (is_dir($path)) {
    return true;
  }

  return @mkdir($path, 0777, true) || is_dir($path);
}

function absolute_to_relative_url($absolutePath) {
  $relative = str_replace(__DIR__, "", (string)$absolutePath);
  $relative = str_replace("\\", "/", $relative);
  if ($relative !== "" && strpos($relative, "/") !== 0) {
    $relative = "/" . $relative;
  }
  return $relative;
}

function archive_demo_asset($sourcePath, $batchTraineeId, $type) {
  $sourcePath = trim((string)$sourcePath);
  if ($sourcePath === "" || !is_file($sourcePath)) {
    return "";
  }

  $extension = strtolower(pathinfo($sourcePath, PATHINFO_EXTENSION));
  if ($extension === "") {
    $extension = $type === "annotated" ? "png" : "jpg";
  }

  $timestamp = time();
  $archiveDir =
    __DIR__
    . "/demo_archive/"
    . intval($batchTraineeId)
    . "/";

  if (!ensure_directory($archiveDir)) {
    respond("error", "Failed to prepare permanent demo archive.");
  }

  $targetPath = $archiveDir . $type . "_" . $timestamp . "." . $extension;
  if (!@copy($sourcePath, $targetPath)) {
    respond("error", "Failed to archive demo image.");
  }

  return absolute_to_relative_url($targetPath);
}

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
  respond("error", "Invalid request.");
}

$batchTraineeId = intval($_POST["batch_trainee_id"] ?? 0);
if ($batchTraineeId <= 0) {
  respond("error", "batch_trainee_id is required.");
}

if (!isset($_FILES["demo_image"])) {
  respond("error", "demo_image is required.");
}

$upload = $_FILES["demo_image"];
if ($upload["error"] !== UPLOAD_ERR_OK) {
  respond("error", "Upload failed.");
}

$uploadsDir = __DIR__ . "/yolo_uploads";
$outputsDir = __DIR__ . "/yolo_outputs";
if (!is_dir($uploadsDir)) {
  mkdir($uploadsDir, 0777, true);
}
if (!is_dir($outputsDir)) {
  mkdir($outputsDir, 0777, true);
}

$ext = pathinfo($upload["name"], PATHINFO_EXTENSION);
$filename = "demo_" . $batchTraineeId . "_" . time() . "." . $ext;
$imagePath = $uploadsDir . "/" . $filename;

if (!move_uploaded_file($upload["tmp_name"], $imagePath)) {
  respond("error", "Failed to save image.");
}

// Run local YOLO inference (no external service)
$pythonCandidates = array_filter(array_unique([
  trim((string)getenv("YOLO_PYTHON_PATH")),
  "python3",
  "python",
  "/usr/local/bin/python3",
  "/usr/bin/python3",
  "C:\\Users\\Kimbap\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
  __DIR__ . "/../yolo_service/.venv/Scripts/python.exe",
  __DIR__ . "/../yolo_service/.venv/bin/python",
]));
$pythonPath = "";
foreach ($pythonCandidates as $candidatePython) {
  if ($candidatePython === "") {
    continue;
  }
  if (str_contains($candidatePython, "\\") || str_contains($candidatePython, "/")) {
    if (file_exists($candidatePython)) {
      $pythonPath = $candidatePython;
      break;
    }
    continue;
  }

  $resolved = trim((string)shell_exec("command -v " . escapeshellarg($candidatePython) . " 2>/dev/null"));
  if ($resolved !== "") {
    $pythonPath = $resolved;
    break;
  }
}
$scriptPath = __DIR__ . "/yolo_infer.py";
$projectRoots = array_values(array_unique(array_filter([
  realpath(__DIR__) ?: __DIR__,
  realpath(__DIR__ . "/..") ?: (__DIR__ . "/.."),
  getenv("YOLO_PROJECT_ROOT") ?: null,
])));
$modelRelativePaths = [
  "welding_api/models/best.pt",
  "models/best.pt",
  "runs\\segment\\runs\\yolo_runs\\welding2026C-v3-seg5\\weights\\best.pt",
  "runs\\yolo_runs\\welding2026C-v3-seg\\weights\\best.pt",
  "runs\\segment\\runs\\yolo_runs\\welding2026C-v3-seg\\weights\\best.pt",
  "runs\\segment\\runs\\yolo_runs\\welding2026C-v2-seg\\weights\\best.pt",
  "runs\\segment\\runs\\yolo_runs\\welding2026C-seg3\\weights\\best.pt",
  "runs\\segment\\runs\\yolo_runs\\welding2026C-seg\\weights\\best.pt",
];
$preferredModelPaths = [];
foreach ($projectRoots as $projectRoot) {
  foreach ($modelRelativePaths as $relativePath) {
    $normalizedRelativePath = str_replace(["\\", "/"], DIRECTORY_SEPARATOR, $relativePath);
    $preferredModelPaths[] = rtrim($projectRoot, "\\/") . DIRECTORY_SEPARATOR . $normalizedRelativePath;
  }
}
$modelPath = getenv("YOLO_MODEL_PATH") ?: "";
if ($modelPath === "") {
  foreach ($preferredModelPaths as $candidatePath) {
    if (file_exists($candidatePath)) {
      $modelPath = $candidatePath;
      break;
    }
  }
}

if (!file_exists($pythonPath)) {
  respond("error", "Local Python not found. Checked: " . implode(", ", $pythonCandidates));
}
if (!file_exists($scriptPath)) {
  respond("error", "Local YOLO script not found. Expected: " . $scriptPath);
}
if (!file_exists($modelPath)) {
  respond("error", "YOLO segmentation model file not found. Train dataset v3 first. Expected one of: " . implode(", ", $preferredModelPaths));
}

$runName = "run_" . time();
$cmd = escapeshellarg($pythonPath)
  . " " . escapeshellarg($scriptPath)
  . " --model " . escapeshellarg($modelPath)
  . " --source " . escapeshellarg($imagePath)
  . " --project " . escapeshellarg($outputsDir)
  . " --name " . escapeshellarg($runName)
  . " 2>&1";

$outputLines = [];
$exitCode = 0;
exec($cmd, $outputLines, $exitCode);
if ($exitCode !== 0) {
  error_log("[assess_demo_yolo.php] YOLO command failed: " . implode("\n", $outputLines));
  respond("error", "YOLO local inference failed. Exit code: " . $exitCode);
}

$payloadRaw = trim(implode("\n", $outputLines));
$payload = json_decode($payloadRaw, true);
if (!is_array($payload)) {
  for ($i = count($outputLines) - 1; $i >= 0; $i--) {
    $candidate = trim((string)$outputLines[$i]);
    if ($candidate === "") {
      continue;
    }
    $decoded = json_decode($candidate, true);
    if (is_array($decoded)) {
      $payload = $decoded;
      $payloadRaw = $candidate;
      break;
    }
  }
}
if (!is_array($payload)) {
  error_log("[assess_demo_yolo.php] Invalid YOLO output: " . $payloadRaw);
  respond("error", "Invalid YOLO local output.");
}

$label = trim($payload["label"] ?? "");
$confidence = trim((string)($payload["confidence"] ?? ""));
$reason = trim($payload["reason"] ?? "");
$detections = is_array($payload["detections"] ?? null) ? $payload["detections"] : [];
$detectionsJson = json_encode($detections, JSON_UNESCAPED_SLASHES);

$goodLabelsRaw = getenv("YOLO_GOOD_LABELS") ?: "good welding,good,ok";
$goodLabels = array_filter(array_map("trim", explode(",", $goodLabelsRaw)));
$detectedLabels = [];
foreach ($detections as $detection) {
  $detectedLabel = strtolower(trim((string)($detection["label"] ?? "")));
  if ($detectedLabel !== "") {
    $detectedLabels[] = $detectedLabel;
  }
}
$labelLower = strtolower($label);
$goodSet = array_map("strtolower", $goodLabels);
$hasDefectDetection = false;
foreach ($detectedLabels as $detectedLabel) {
  if (!in_array($detectedLabel, $goodSet, true)) {
    $hasDefectDetection = true;
    break;
  }
}
$isGood = !$hasDefectDetection && ($labelLower === "" || in_array($labelLower, $goodSet, true));
$outputImage = $payload["output_image"] ?? "";

$annotatedUrl = "";
if ($outputImage && file_exists($outputImage)) {
  $annotatedUrl = absolute_to_relative_url($outputImage);
}

$originalRelative = absolute_to_relative_url($imagePath);

$demoStatus = $isGood ? "competent" : "not_yet_competent";

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT oral_status, written_status
    FROM trainee_progress
    WHERE batch_trainee_id = ?
  ");
  $stmt->execute([$batchTraineeId]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);
  $oralStatus = $row["oral_status"] ?? "pending";
  $writtenStatus = $row["written_status"] ?? "pending";

  if (!($oralStatus === "competent" && $writtenStatus === "competent")) {
    respond("error", "Demo is locked. Oral and Written must both be Competent.");
  }

  $demoDate = date("Y-m-d");
  $demoImageUrl = archive_demo_asset($imagePath, $batchTraineeId, "original");
  $demoAnnotatedUrl = archive_demo_asset($outputImage, $batchTraineeId, "annotated");
  if ($row) {
    $stmt = $pdo->prepare("
      UPDATE trainee_progress
      SET demo_status = ?, demo_date_completed = ?, demo_image_url = ?, demo_annotated_image_url = ?,
          demo_label = ?, demo_confidence = ?, demo_reason = ?, demo_detections_json = ?, updated_at = NOW()
      WHERE batch_trainee_id = ?
    ");
    $stmt->execute([
      $demoStatus,
      $demoDate,
      $demoImageUrl,
      $demoAnnotatedUrl,
      $label,
      $confidence,
      $reason,
      $detectionsJson,
      $batchTraineeId
    ]);
  } else {
    $stmt = $pdo->prepare("
      INSERT INTO trainee_progress
        (batch_trainee_id, oral_status, written_status, demo_status,
         oral_date_completed, written_date_completed, demo_date_completed,
         demo_image_url, demo_annotated_image_url, demo_label, demo_confidence,
         demo_reason, demo_detections_json, updated_at)
      VALUES (?, 'pending', 'pending', ?, NULL, NULL, ?, ?, ?, ?, ?, ?, NOW())
    ");
    $stmt->execute([
      $batchTraineeId,
      $demoStatus,
      $demoDate,
      $demoImageUrl,
      $demoAnnotatedUrl,
      $label,
      $confidence,
      $reason,
      $detectionsJson
    ]);
  }
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}

  respond("success", "Assessment complete.", [
  "label" => $label,
  "confidence" => $confidence,
  "detections" => $detections,
  "reason" => $reason,
  "demo_status" => $demoStatus,
  "annotated_image_url" => $demoAnnotatedUrl,
  "original_image_url" => $demoImageUrl,
  "model_path" => $modelPath,
]);
