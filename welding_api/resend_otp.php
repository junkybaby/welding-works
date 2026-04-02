<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$email = strtolower(trim($data["email"] ?? ""));

if ($email === "") {
  respond("error", "Email is required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, is_verified
    FROM users
    WHERE email = ?
    LIMIT 1
  ");
  $stmt->execute([$email]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  if (!$row) {
    respond("error", "Account not found.");
  }

  if ((int)$row["is_verified"] === 1) {
    respond("success", "Account already verified.");
  }

  $otp = generate_otp();
  $update = $pdo->prepare("
    UPDATE users
    SET verification_code = ?
    WHERE id = ?
  ");
  $update->execute([$otp, $row["id"]]);

  $sent = send_otp_email($email, $otp);
  if (!$sent) {
    respond("error", "Failed to send OTP email.", [
      "otp" => $otp,
      "debug" => ["mail_error" => mail_last_error()],
    ]);
  }

  respond("success", "OTP resent.", ["otp" => $otp]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
