<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$email = strtolower(trim($data["email"] ?? ""));
$password = $data["password"] ?? "";

if ($email === "" || $password === "") {
  respond("error", "Email and password are required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, password, role, email, username, is_verified
    FROM users
    WHERE email = ?
    LIMIT 1
  ");
  $stmt->execute([$email]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  if (!$row || $row["role"] !== "admin") {
    respond("error", "Account not found.");
  }

  if (!password_verify($password, $row["password"])) {
    respond("error", "Invalid credentials.");
  }

  if ((int)$row["is_verified"] === 0) {
    respond("error", "Account not verified.");
  }

  $token = bin2hex(random_bytes(32));
  $expiresAt = date("Y-m-d H:i:s", time() + (60 * 60 * 8));
  $insert = $pdo->prepare("
    INSERT INTO admin_sessions (user_id, token, created_at, expires_at)
    VALUES (?, ?, NOW(), ?)
  ");
  $insert->execute([$row["id"], $token, $expiresAt]);

  audit_log("admin_login", $row["email"], $row["role"], "user", $row["id"]);
  respond("success", "Login successful.", [
    "token" => $token,
    "email" => $row["email"],
    "username" => $row["username"],
  ]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
