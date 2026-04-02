<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$email = strtolower(trim($data["email"] ?? ""));
$otp = trim($data["otp"] ?? "");

if ($email === "" || $otp === "") {
  respond("error", "Email and OTP are required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, verification_code, email, username
    FROM users
    WHERE email = ?
    LIMIT 1
  ");
  $stmt->execute([$email]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  if (!$row) {
    respond("error", "Account not found.");
  }

  if ($row["verification_code"] !== $otp) {
    respond("error", "Invalid OTP.");
  }

  $update = $pdo->prepare("
    UPDATE users
    SET is_verified = 1, verification_code = NULL
    WHERE id = ?
  ");
  $update->execute([$row["id"]]);

  respond("success", "OTP verified.", [
    "email" => $row["email"],
    "username" => $row["username"],
  ]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
