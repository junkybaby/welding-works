<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$email = strtolower(trim($data["email"] ?? ""));
$role = trim($data["role"] ?? "");

if ($email === "") {
  respond("error", "Email is required.");
}

audit_log("logout", $email, $role, "user", "");
respond("success", "Logged out.");
