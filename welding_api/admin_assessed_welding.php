<?php
require_once __DIR__ . "/db.php";
require_once __DIR__ . "/admin_auth.php";

$admin = require_admin();
$data = read_json();
$batchStatus = trim($data["batch_status"] ?? "");
$trainerSearch = trim($data["trainer_search"] ?? "");

$allowedStatus = ["", "active", "archived"];
if (!in_array($batchStatus, $allowedStatus, true)) {
  respond("error", "Invalid batch status.");
}

try {
  $pdo = db();

  $where = [];
  $params = [];

  if ($batchStatus !== "") {
    $where[] = "b.status = ?";
    $params[] = $batchStatus;
  }

  if ($trainerSearch !== "") {
    $searchTerm = "%" . strtolower($trainerSearch) . "%";
    $where[] = "(
      LOWER(COALESCE(u.firstname, '')) LIKE ?
      OR LOWER(COALESCE(u.middlename, '')) LIKE ?
      OR LOWER(COALESCE(u.lastname, '')) LIKE ?
      OR LOWER(COALESCE(u.email, '')) LIKE ?
      OR LOWER(CONCAT_WS(' ', COALESCE(u.firstname, ''), COALESCE(u.middlename, ''), COALESCE(u.lastname, ''))) LIKE ?
      OR LOWER(CONCAT_WS(' ', COALESCE(u.firstname, ''), COALESCE(u.lastname, ''))) LIKE ?
      OR LOWER(COALESCE(b.trainer_email, '')) LIKE ?
    )";
    array_push($params, $searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm);
  }

  $whereSql = empty($where) ? "" : ("WHERE " . implode(" AND ", $where));

  $batchStmt = $pdo->prepare("
    SELECT
      b.id,
      b.name,
      b.status,
      b.created_at,
      b.archived_at,
      b.trainer_email,
      b.trainer_username,
      u.firstname AS trainer_firstname,
      u.middlename AS trainer_middlename,
      u.lastname AS trainer_lastname,
      COUNT(bt.id) AS trainee_count,
      SUM(CASE WHEN bt.result <> 'Pending' THEN 1 ELSE 0 END) AS assessed_count
    FROM batches b
    LEFT JOIN users u ON u.email = b.trainer_email
    LEFT JOIN batch_trainees bt ON bt.batch_id = b.id
    {$whereSql}
    GROUP BY
      b.id, b.name, b.status, b.created_at, b.archived_at, b.trainer_email, b.trainer_username,
      u.firstname, u.middlename, u.lastname
    ORDER BY b.created_at DESC, b.id DESC
  ");
  $batchStmt->execute($params);
  $batches = $batchStmt->fetchAll(PDO::FETCH_ASSOC);

  $traineeStmt = $pdo->prepare("
    SELECT
      bt.id,
      bt.batch_id,
      bt.trainee_name,
      bt.training_center,
      bt.status,
      bt.result,
      tp.oral_status,
      tp.written_status,
      tp.demo_status,
      tp.oral_date_completed,
      tp.written_date_completed,
      tp.demo_date_completed,
      tp.demo_image_url,
      tp.demo_annotated_image_url,
      tp.performance_criteria_json,
      tp.updated_at
    FROM batch_trainees bt
    LEFT JOIN trainee_progress tp ON tp.batch_trainee_id = bt.id
    WHERE bt.batch_id = ?
    ORDER BY bt.id ASC
  ");

  $resolveAssessedDate = function ($row) {
    $dates = [];
    foreach (["demo_date_completed", "written_date_completed", "oral_date_completed"] as $field) {
      $value = trim((string)($row[$field] ?? ""));
      if ($value !== "") {
        $dates[] = $value;
      }
    }
    if (empty($dates)) {
      return "";
    }
    rsort($dates, SORT_STRING);
    return $dates[0];
  };

  $result = [];
  foreach ($batches as $batch) {
    $traineeStmt->execute([$batch["id"]]);
    $trainees = $traineeStmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($trainees as $index => $trainee) {
      $trainees[$index]["assessed_date"] = $resolveAssessedDate($trainee);
    }

    $result[] = [
      "id" => (int)$batch["id"],
      "name" => $batch["name"],
      "status" => $batch["status"],
      "created_at" => $batch["created_at"],
      "archived_at" => $batch["archived_at"],
      "trainer_email" => $batch["trainer_email"],
      "trainer_username" => $batch["trainer_username"],
      "trainer_firstname" => $batch["trainer_firstname"],
      "trainer_middlename" => $batch["trainer_middlename"],
      "trainer_lastname" => $batch["trainer_lastname"],
      "trainee_count" => (int)$batch["trainee_count"],
      "assessed_count" => (int)$batch["assessed_count"],
      "trainees" => $trainees,
    ];
  }

  audit_log("admin_viewed_assessed_welding", $admin["email"], $admin["role"], "batch", "", [
    "batch_status" => $batchStatus,
    "trainer_search" => $trainerSearch,
    "batch_count" => count($result),
  ], $admin["user_id"]);

  respond("success", "OK", ["batches" => $result]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
