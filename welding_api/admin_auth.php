<?php
require_once __DIR__ . "/db.php";

function get_bearer_token() {
  $headers = getallheaders();
  $auth = $headers["Authorization"] ?? $headers["authorization"] ?? "";
  if (stripos($auth, "Bearer ") === 0) {
    return trim(substr($auth, 7));
  }
  return "";
}

function require_admin() {
  $token = get_bearer_token();
  if ($token === "") {
    respond("error", "Missing token.");
  }

  try {
    $pdo = db();
    $stmt = $pdo->prepare("
      SELECT s.user_id, u.email, u.username, u.role
      FROM admin_sessions s
      JOIN users u ON u.id = s.user_id
      WHERE s.token = ? AND s.expires_at > NOW()
      LIMIT 1
    ");
    $stmt->execute([$token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row || $row["role"] !== "admin") {
      respond("error", "Unauthorized.");
    }
    return [
      "user_id" => (int)$row["user_id"],
      "email" => $row["email"],
      "username" => $row["username"],
      "role" => $row["role"],
      "token" => $token,
    ];
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}
