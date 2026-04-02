<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$batchTraineeId = intval($data["batch_trainee_id"] ?? 0);

if ($batchTraineeId <= 0) {
  respond("error", "batch_trainee_id is required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT oral_status, written_status, demo_status,
           oral_date_completed, written_date_completed, demo_date_completed,
           demo_image_url, demo_annotated_image_url,
           demo_label, demo_confidence, demo_reason, demo_detections_json,
           performance_criteria_json
    FROM trainee_progress
    WHERE batch_trainee_id = ?
  ");
  $stmt->execute([$batchTraineeId]);
  $row = $stmt->fetch(PDO::FETCH_ASSOC);

  if (!$row) {
    respond("success", "OK", [
      "progress" => [
        "oral_status" => "pending",
        "written_status" => "pending",
        "demo_status" => "pending",
        "oral_date_completed" => null,
        "written_date_completed" => null,
        "demo_date_completed" => null,
        "demo_image_url" => null,
        "demo_annotated_image_url" => null,
        "demo_label" => null,
        "demo_confidence" => null,
        "demo_reason" => null,
        "demo_detections_json" => null,
        "performance_criteria_json" => null,
      ],
    ]);
  }

  respond("success", "OK", ["progress" => $row]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
