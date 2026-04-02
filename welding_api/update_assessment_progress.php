<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$batchTraineeId = intval($data["batch_trainee_id"] ?? 0);
$assessmentType = strtolower(trim($data["assessment_type"] ?? ""));
$status = strtolower(trim($data["status"] ?? ""));

if ($batchTraineeId <= 0 || $assessmentType === "" || $status === "") {
  respond("error", "Missing required fields.");
}

$allowedTypes = ["oral", "written", "demo"];
$allowedStatuses = ["competent", "not_yet_competent", "pending"];

if (!in_array($assessmentType, $allowedTypes, true)) {
  respond("error", "Invalid assessment type.");
}

if (!in_array($status, $allowedStatuses, true)) {
  respond("error", "Invalid status.");
}

$dbStatus = $status === "not_yet_competent" ? "not_yet_competent" : $status;
$dateColumn = "{$assessmentType}_date_completed";
$statusColumn = "{$assessmentType}_status";
$dateValue = $status === "pending" ? null : date("Y-m-d");

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT batch_trainee_id
    FROM trainee_progress
    WHERE batch_trainee_id = ?
  ");
  $stmt->execute([$batchTraineeId]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  if ($row) {
    $stmt = $pdo->prepare("
      UPDATE trainee_progress
      SET {$statusColumn} = ?, {$dateColumn} = ?, updated_at = NOW()
      WHERE batch_trainee_id = ?
    ");
    $stmt->execute([$dbStatus, $dateValue, $batchTraineeId]);
  } else {
    $stmt = $pdo->prepare("
      INSERT INTO trainee_progress
        (batch_trainee_id, oral_status, written_status, demo_status,
         oral_date_completed, written_date_completed, demo_date_completed, updated_at)
      VALUES (?, 'pending', 'pending', 'pending', NULL, NULL, NULL, NOW())
    ");
    $stmt->execute([$batchTraineeId]);
    $stmt = $pdo->prepare("
      UPDATE trainee_progress
      SET {$statusColumn} = ?, {$dateColumn} = ?, updated_at = NOW()
      WHERE batch_trainee_id = ?
    ");
    $stmt->execute([$dbStatus, $dateValue, $batchTraineeId]);
  }

  respond("success", "Progress updated.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
