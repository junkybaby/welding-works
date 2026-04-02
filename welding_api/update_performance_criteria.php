<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$batchTraineeId = intval($data["batch_trainee_id"] ?? 0);
$scores = $data["criteria_scores"] ?? null;

if ($batchTraineeId <= 0) {
  respond("error", "batch_trainee_id is required.");
}

if (!is_array($scores)) {
  respond("error", "criteria_scores is required.");
}

try {
  $pdo = db();
  $payload = json_encode($scores);

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
      SET performance_criteria_json = ?, updated_at = NOW()
      WHERE batch_trainee_id = ?
    ");
    $stmt->execute([$payload, $batchTraineeId]);
  } else {
    $stmt = $pdo->prepare("
      INSERT INTO trainee_progress
        (batch_trainee_id, oral_status, written_status, demo_status,
         oral_date_completed, written_date_completed, demo_date_completed,
         performance_criteria_json, updated_at)
      VALUES (?, 'pending', 'pending', 'pending', NULL, NULL, NULL, ?, NOW())
    ");
    $stmt->execute([$batchTraineeId, $payload]);
  }

  respond("success", "Criteria saved.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
