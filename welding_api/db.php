<?php
// Load local .env if present (for XAMPP/local dev).
if (!function_exists("load_local_env")) {
  function load_local_env() {
    static $loaded = false;
    if ($loaded) return;
    $loaded = true;

    $envPath = __DIR__ . "/.env";
    if (!file_exists($envPath)) return;

    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!is_array($lines)) return;

    foreach ($lines as $line) {
      $line = trim($line);
      if ($line === "" || str_starts_with($line, "#")) continue;
      $parts = explode("=", $line, 2);
      if (count($parts) !== 2) continue;
      $key = trim($parts[0]);
      $value = trim($parts[1]);
      if ($key === "" || getenv($key) !== false) continue;
      putenv("{$key}={$value}");
      $_ENV[$key] = $value;
    }
  }
}
load_local_env();

// DB config (supports Railway MySQL env vars or manual overrides)
$DB_HOST = getenv("DB_HOST") ?: (getenv("MYSQLHOST") ?: "localhost");
$DB_PORT = getenv("DB_PORT") ?: (getenv("MYSQLPORT") ?: "3306");
$DB_NAME = getenv("DB_NAME") ?: (getenv("MYSQLDATABASE") ?: "welding_works");
// Local defaults for XAMPP/MySQL80; env vars still override in production.
$DB_USER = getenv("DB_USER") ?: (getenv("MYSQLUSER") ?: "root");
$DB_PASS = getenv("DB_PASS") ?: (getenv("MYSQLPASSWORD") ?: "");

header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Max-Age: 86400");
header("Vary: Origin");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
  http_response_code(204);
  exit;
}

function db() {
  global $DB_HOST, $DB_PORT, $DB_NAME, $DB_USER, $DB_PASS;
  $dsn = "mysql:host={$DB_HOST};port={$DB_PORT};dbname={$DB_NAME};charset=utf8mb4";
  $pdo = new PDO($dsn, $DB_USER, $DB_PASS, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
  ]);
  return $pdo;
}

function read_json() {
  $raw = file_get_contents("php://input");
  if (!$raw) return [];
  $data = json_decode($raw, true);
  return is_array($data) ? $data : [];
}

function respond($status, $message, $extra = []) {
  $payload = array_merge([
    "status" => $status,
    "message" => $message,
  ], $extra);

  $showOtp = getenv("DEV_SHOW_OTP") === "1";
  if (!$showOtp) {
    $clientIp = $_SERVER["REMOTE_ADDR"] ?? "";
    $showOtp = $clientIp === "127.0.0.1" || $clientIp === "::1";
    if (!$showOtp && $clientIp !== "") {
      $showOtp =
        str_starts_with($clientIp, "10.") ||
        str_starts_with($clientIp, "192.168.") ||
        preg_match("/^172\\.(1[6-9]|2\\d|3[0-1])\\./", $clientIp);
    }
  }

  if ($showOtp && isset($payload["otp"])) {
    $payload["debug"] = array_merge(
      is_array($payload["debug"] ?? null) ? $payload["debug"] : [],
      ["otp" => $payload["otp"]]
    );
  }

  if (!$showOtp && array_key_exists("otp", $payload)) {
    unset($payload["otp"]);
  }

  if (!$showOtp && isset($payload["debug"])) {
    unset($payload["debug"]);
  }

  echo json_encode($payload);
  exit;
}

function generate_otp() {
  return strval(random_int(100000, 999999));
}

function mail_last_error() {
  return $GLOBALS["MAIL_LAST_ERROR"] ?? null;
}

function send_otp_email($email, $otp) {
  $subject = "Your Welding Works OTP";
  $bodyText = "Your OTP code is: {$otp}\n\nThis code will expire soon.";
  require_once __DIR__ . "/send_mail.php";
  return send_mail($email, $subject, $bodyText);
}

function audit_log($action, $actorEmail = "", $actorRole = "", $targetType = "", $targetId = "", $details = [], $actorUserId = null) {
  try {
    $pdo = db();
    if ($actorUserId === null && $actorEmail !== "") {
      $lookup = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
      $lookup->execute([$actorEmail]);
      $actorUserId = $lookup->fetchColumn() ?: null;
    }
    $stmt = $pdo->prepare("
      INSERT INTO audit_logs (actor_email, actor_role, actor_user_id, action, target_type, target_id, details, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ");
    $stmt->execute([
      $actorEmail,
      $actorRole,
      $actorUserId,
      $action,
      $targetType,
      $targetId,
      json_encode($details),
    ]);
  } catch (Throwable $e) {
    // Do not block app flow on audit log errors.
  }
}
