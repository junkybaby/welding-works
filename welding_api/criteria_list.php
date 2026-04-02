<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$type = trim($data["type"] ?? "");
$onlyActive = isset($data["active"]) ? intval($data["active"]) : 1;

try {
  $pdo = db();
  $where = [];
  $params = [];

  if ($type !== "") {
    $where[] = "type = ?";
    $params[] = $type;
  }
  if ($onlyActive === 1) {
    $where[] = "active = 1";
  }

  $whereSql = $where ? ("WHERE " . implode(" AND ", $where)) : "";
  $stmt = $pdo->prepare("
    SELECT id, type, category, title, weight_percent, scale_range, remark, active, sort_order, updated_at, created_at
    FROM criteria
    {$whereSql}
    ORDER BY
      CASE category
        WHEN 'Basic' THEN 1
        WHEN 'Common' THEN 2
        WHEN 'Core' THEN 3
        WHEN 'Grading' THEN 4
        WHEN 'Scale' THEN 5
        ELSE 99
      END,
      sort_order ASC,
      id ASC
  ");
  $stmt->execute($params);
  $criteria = $stmt->fetchAll(PDO::FETCH_ASSOC);
  respond("success", "OK", ["criteria" => $criteria]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
