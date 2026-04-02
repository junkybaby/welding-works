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
      SELECT id, type, category, title, weight_percent, scale_range, remark, active, sort_order, updated_at, created_at
      FROM criteria
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
    $criteria = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respond("success", "OK", ["criteria" => $criteria]);
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

if ($action === "create") {
  $type = trim($data["type"] ?? "competency");
  $category = trim($data["category"] ?? "");
  $title = trim($data["title"] ?? "");
  $sortOrder = intval($data["sort_order"] ?? 0);
  $active = isset($data["active"]) ? intval($data["active"]) : 1;
  $weightPercent = $data["weight_percent"] ?? null;
  $scaleRange = trim($data["scale_range"] ?? "");
  $remark = trim($data["remark"] ?? "");

  $allowedTypes = ["competency", "grading", "assessment"];
  if (!in_array($type, $allowedTypes, true)) {
    respond("error", "Invalid type.");
  }

  if ($category === "" || $title === "") {
    respond("error", "Category and title are required.");
  }

  try {
    $pdo = db();
    $stmt = $pdo->prepare("
      INSERT INTO criteria (type, category, title, user_id, weight_percent, scale_range, remark, active, sort_order, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ");
    $stmt->execute([
      $type,
      $category,
      $title,
      $admin["id"] ?? null,
      ($weightPercent === "" || $weightPercent === null) ? null : $weightPercent,
      $scaleRange !== "" ? $scaleRange : null,
      $remark !== "" ? $remark : null,
      $active,
      $sortOrder,
    ]);
    $id = $pdo->lastInsertId();
    audit_log("criteria_created", $admin["email"], $admin["role"], "criteria", $id, [
      "type" => $type,
      "category" => $category,
      "title" => $title,
    ]);
    respond("success", "Criteria created.");
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

if ($action === "update") {
  $id = intval($data["id"] ?? 0);
  if ($id <= 0) {
    respond("error", "Id is required.");
  }

  $type = trim($data["type"] ?? "");
  $category = trim($data["category"] ?? "");
  $title = trim($data["title"] ?? "");
  $sortOrder = intval($data["sort_order"] ?? 0);
  $active = isset($data["active"]) ? intval($data["active"]) : 1;
  $weightPercent = $data["weight_percent"] ?? null;
  $scaleRange = trim($data["scale_range"] ?? "");
  $remark = trim($data["remark"] ?? "");

  try {
    $pdo = db();
    $stmt = $pdo->prepare("
      UPDATE criteria
      SET type = COALESCE(NULLIF(?, ''), type),
          category = ?, title = ?,
          user_id = ?,
          weight_percent = ?,
          scale_range = ?,
          remark = ?,
          sort_order = ?, active = ?, updated_at = NOW()
      WHERE id = ?
    ");
    $stmt->execute([
      $type,
      $category,
      $title,
      $admin["id"] ?? null,
      ($weightPercent === "" || $weightPercent === null) ? null : $weightPercent,
      $scaleRange !== "" ? $scaleRange : null,
      $remark !== "" ? $remark : null,
      $sortOrder,
      $active,
      $id,
    ]);
    audit_log("criteria_updated", $admin["email"], $admin["role"], "criteria", $id, [
      "type" => $type,
      "category" => $category,
      "title" => $title,
    ]);
    respond("success", "Criteria updated.");
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

if ($action === "delete") {
  $id = intval($data["id"] ?? 0);
  if ($id <= 0) {
    respond("error", "Id is required.");
  }
  try {
    $pdo = db();
    $stmt = $pdo->prepare("DELETE FROM criteria WHERE id = ?");
    $stmt->execute([$id]);
    audit_log("criteria_deleted", $admin["email"], $admin["role"], "criteria", $id);
    respond("success", "Criteria deleted.");
  } catch (Throwable $e) {
    respond("error", "Server error: " . $e->getMessage());
  }
}

respond("error", "Invalid action.");
