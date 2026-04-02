<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$first = trim($data["first_name"] ?? "");
$middle = trim($data["middle_name"] ?? "");
$last = trim($data["last_name"] ?? "");
$email = strtolower(trim($data["email"] ?? ""));
$password = $data["password"] ?? "";
$role = trim($data["role"] ?? "trainee");
$status = trim($data["status"] ?? "active");

if ($first === "" || $last === "" || $email === "" || $password === "") {
  respond("error", "Missing required fields.");
}

if (!str_ends_with($email, "@gmail.com")) {
  respond("error", "Only Gmail accounts allowed.");
}

$username = trim($data["username"] ?? "");
if ($username === "") {
  $username = explode("@", $email)[0];
}
$passwordHash = password_hash($password, PASSWORD_DEFAULT);
$otp = generate_otp();

try {
  $pdo = db();
  $check = $pdo->prepare("
    SELECT id, is_verified
    FROM users
    WHERE email = ? OR username = ?
    LIMIT 1
  ");
  $check->execute([$email, $username]);
  $existing = $check->fetch(PDO::FETCH_ASSOC);
  if ($existing && (int)$existing["is_verified"] === 1) {
    respond("error", "Account already exists.");
  }

  if ($existing) {
    $update = $pdo->prepare("
      UPDATE users
      SET firstname = ?, middlename = ?, lastname = ?, username = ?,
          password = ?, email = ?, role = ?, status = ?,
          verification_code = ?, is_verified = 0, password_change = 0
      WHERE id = ?
    ");
    $update->execute([
      $first, $middle, $last, $username, $passwordHash, $email, $role,
      $status !== "" ? $status : "active",
      $otp, $existing["id"]
    ]);
    audit_log("user_updated", $email, $role, "user", $existing["id"]);
  } else {
    $stmt = $pdo->prepare("
      INSERT INTO users
        (firstname, middlename, lastname, username, password, email, role,
         status, verification_code, is_verified, password_change, created_at)
      VALUES
        (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, NOW())
    ");
    $stmt->execute([
      $first, $middle, $last, $username, $passwordHash, $email, $role,
      $status !== "" ? $status : "active",
      $otp
    ]);
    $newId = $pdo->lastInsertId();
    audit_log("user_created", $email, $role, "user", $newId);
  }

  $sent = send_otp_email($email, $otp);
  if (!$sent) {
    respond("error", "Failed to send OTP email.", [
      "otp" => $otp,
      "debug" => ["mail_error" => mail_last_error()],
    ]);
  }

  respond("success", "Registration successful. OTP sent.", ["otp" => $otp]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
