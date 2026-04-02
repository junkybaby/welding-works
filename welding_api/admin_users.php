<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$admin = require_admin();
$data = read_json();
$action = $data["action"] ?? "list";

if ($action === "list") {
  try {
    $pdo = db();
    $stmt = $pdo->query("
      SELECT id, firstname, middlename, lastname, username, email, role, status, is_verified, created_at
      FROM users
      ORDER BY created_at DESC
    ");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respond("success", "OK", ["users" => $users]);
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

if ($action === "create") {
  $first = trim($data["first_name"] ?? "");
  $middle = trim($data["middle_name"] ?? "");
  $last = trim($data["last_name"] ?? "");
  $email = strtolower(trim($data["email"] ?? ""));
  $username = trim($data["username"] ?? "");
  $password = $data["password"] ?? "";
  $status = trim($data["status"] ?? "active");

  if ($first === "" || $last === "" || $email === "" || $username === "" || $password === "") {
    respond("error", "First name, last name, email, username, and password are required.");
  }

  if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond("error", "Invalid email address.");
  }

  if (strlen($password) < 8) {
    respond("error", "Password must be at least 8 characters.");
  }

  $allowedStatus = ["active", "inactive"];
  if (!in_array($status, $allowedStatus, true)) {
    respond("error", "Invalid status.");
  }

  try {
    $pdo = db();
    $check = $pdo->prepare("
      SELECT id
      FROM users
      WHERE email = ? OR username = ?
      LIMIT 1
    ");
    $check->execute([$email, $username]);
    if ($check->fetch(PDO::FETCH_ASSOC)) {
      respond("error", "A user with that email or username already exists.");
    }

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $pdo->prepare("
      INSERT INTO users
        (firstname, middlename, lastname, username, password, email, role, status, is_verified, password_change, verification_code, created_at)
      VALUES
        (?, ?, ?, ?, ?, ?, 'trainer', ?, 1, 0, NULL, NOW())
    ");
    $stmt->execute([
      $first,
      $middle !== "" ? $middle : null,
      $last,
      $username,
      $passwordHash,
      $email,
      $status,
    ]);

    $newId = (int)$pdo->lastInsertId();
    audit_log("trainer_created", $admin["email"], $admin["role"], "user", $newId, [
      "email" => $email,
      "username" => $username,
      "status" => $status,
    ], $admin["user_id"]);
    respond("success", "Trainer account created.", ["user_id" => $newId]);
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

if ($action === "update") {
  $userId = intval($data["user_id"] ?? 0);
  if ($userId <= 0) {
    respond("error", "User id is required.");
  }

  $role = trim($data["role"] ?? "");
  $status = trim($data["status"] ?? "");
  $isVerified = isset($data["is_verified"]) ? intval($data["is_verified"]) : null;

  $allowedRoles = ["admin", "trainer"];
  $allowedStatus = ["active", "inactive"];

  if ($role !== "" && !in_array($role, $allowedRoles, true)) {
    respond("error", "Invalid role.");
  }
  if ($status !== "" && !in_array($status, $allowedStatus, true)) {
    respond("error", "Invalid status.");
  }

  try {
    $pdo = db();
    $stmt = $pdo->prepare("
      UPDATE users
      SET
        role = COALESCE(NULLIF(?, ''), role),
        status = COALESCE(NULLIF(?, ''), status),
        is_verified = COALESCE(?, is_verified)
      WHERE id = ?
    ");
    $stmt->execute([$role, $status, $isVerified, $userId]);
    audit_log("user_updated", $admin["email"], $admin["role"], "user", $userId, [
      "role" => $role,
      "status" => $status,
      "is_verified" => $isVerified,
    ]);
    respond("success", "User updated.");
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

respond("error", "Invalid action.");
