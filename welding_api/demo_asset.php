<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$token = "";
$headers = function_exists("getallheaders") ? getallheaders() : [];
if (is_array($headers)) {
  foreach ($headers as $key => $value) {
    if (strtolower((string)$key) === "authorization") {
      $token = trim((string)$value);
      break;
    }
  }
}

if ($token !== "") {
  require_admin();
}

$path = trim((string)($_GET["path"] ?? ""));
if ($path === "") {
  http_response_code(400);
  exit("Missing asset path.");
}

$normalizedPath = str_replace("\\", "/", $path);
if ($normalizedPath[0] !== "/") {
  $normalizedPath = "/" . $normalizedPath;
}

$allowedPrefixes = [
  "/yolo_uploads/",
  "/yolo_outputs/",
  "/demo_archive/",
  "/welding_api/yolo_uploads/",
  "/welding_api/yolo_outputs/",
  "/welding_api/demo_archive/",
];

$allowed = false;
foreach ($allowedPrefixes as $prefix) {
  if (strpos($normalizedPath, $prefix) === 0) {
    $allowed = true;
    break;
  }
}

if (!$allowed || strpos($normalizedPath, "..") !== false) {
  http_response_code(400);
  exit("Invalid asset path.");
}

$relativePath = preg_replace('#^/welding_api/#', '/', $normalizedPath);
$safeRelativePath = ltrim(str_replace("/", DIRECTORY_SEPARATOR, $relativePath), DIRECTORY_SEPARATOR);
$candidateRoots = array_values(array_unique(array_filter([
  __DIR__,
  getenv("WELDING_API_ASSET_ROOT") ?: "",
  "C:\\xampp\\htdocs\\welding_api",
])));

$fullPath = "";
foreach ($candidateRoots as $root) {
  $candidatePath = rtrim($root, "\\/") . DIRECTORY_SEPARATOR . $safeRelativePath;
  if (is_file($candidatePath)) {
    $fullPath = $candidatePath;
    break;
  }
}

if ($fullPath === "") {
  http_response_code(404);
  exit("Asset not found.");
}

$mimeType = function_exists("mime_content_type")
  ? mime_content_type($fullPath)
  : "application/octet-stream";

header("Content-Type: " . ($mimeType ?: "application/octet-stream"));
header("Content-Length: " . filesize($fullPath));
header('Content-Disposition: inline; filename="' . basename($fullPath) . '"');
readfile($fullPath);
exit;
