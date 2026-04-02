<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$admin = require_admin();
$data = read_json();
$limit = intval($data["limit"] ?? 100);
$offset = intval($data["offset"] ?? 0);

if ($limit <= 0) $limit = 100;
if ($limit > 500) $limit = 500;
if ($offset < 0) $offset = 0;

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, actor_email, actor_role, action, target_type, target_id, details, created_at
    FROM audit_logs
    ORDER BY created_at DESC
    LIMIT ? OFFSET ?
  ");
  $stmt->bindValue(1, $limit, PDO::PARAM_INT);
  $stmt->bindValue(2, $offset, PDO::PARAM_INT);
  $stmt->execute();
  $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
  respond("success", "OK", ["logs" => $logs]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
