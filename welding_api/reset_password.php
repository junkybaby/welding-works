<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$email = strtolower(trim($data["email"] ?? ""));
$otp = trim($data["otp"] ?? "");
$password = $data["password"] ?? "";

if ($email === "" || $otp === "" || $password === "") {
  respond("error", "Email, OTP, and password are required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, password, verification_code
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

  if (password_verify($password, $row["password"])) {
    respond("error", "New password must be different from the old password.");
  }

  $passwordHash = password_hash($password, PASSWORD_DEFAULT);
  $update = $pdo->prepare("
    UPDATE users
    SET password = ?, verification_code = NULL, is_verified = 1, password_change = 1
    WHERE id = ?
  ");
  $update->execute([$passwordHash, $row["id"]]);

  audit_log("password_reset", $email, "", "user", $row["id"]);
  respond("success", "Password reset successful.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
