<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$admin = require_admin();

try {
  $pdo = db();
  $stmt = $pdo->prepare("DELETE FROM admin_sessions WHERE token = ?");
  $stmt->execute([$admin["token"]]);
  audit_log("admin_logout", $admin["email"], $admin["role"], "user", $admin["user_id"]);
  respond("success", "Logged out.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
