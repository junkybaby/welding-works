<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$trainerEmail = strtolower(trim($data["trainer_email"] ?? ""));

if ($trainerEmail === "") {
  respond("error", "Trainer email is required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    SELECT id, name, created_at
    FROM batches
    WHERE trainer_email = ? AND status = 'active'
    ORDER BY created_at DESC
  ");
  $stmt->execute([$trainerEmail]);
  $batches = $stmt->fetchAll(PDO::FETCH_ASSOC);

  $result = [];
  $tstmt = $pdo->prepare("
    SELECT bt.id, bt.trainee_name, bt.training_center, bt.status, bt.result,
           tp.demo_date_completed, tp.written_date_completed, tp.oral_date_completed
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

  foreach ($batches as $batch) {
    $tstmt->execute([$batch["id"]]);
    $trainees = $tstmt->fetchAll(PDO::FETCH_ASSOC);
    foreach ($trainees as $index => $trainee) {
      $trainees[$index]["assessed_date"] = $resolveAssessedDate($trainee);
    }
    $trainingCenter = "";
    if (!empty($trainees)) {
      $trainingCenter = $trainees[0]["training_center"] ?? "";
    }
    $result[] = [
      "id" => (int)$batch["id"],
      "name" => $batch["name"],
      "training_center" => $trainingCenter,
      "created_at" => $batch["created_at"],
      "trainees" => $trainees,
    ];
  }

  respond("success", "OK", ["batches" => $result]);
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
