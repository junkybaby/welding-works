<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$batchId = intval($data["batch_id"] ?? 0);
$trainingCenter = trim($data["training_center"] ?? "");
$trainees = $data["trainees"] ?? [];

if ($batchId <= 0 || $trainingCenter === "") {
  respond("error", "Missing required fields.");
}

if (!is_array($trainees)) {
  respond("error", "Invalid trainees list.");
}

try {
  $pdo = db();
  $pdo->beginTransaction();

  $stmt = $pdo->prepare("
    UPDATE batch_trainees
    SET training_center = ?
    WHERE batch_id = ?
  ");
  $stmt->execute([$trainingCenter, $batchId]);

  $updateStmt = $pdo->prepare("
    UPDATE batch_trainees
    SET trainee_name = ?
    WHERE id = ? AND batch_id = ?
  ");

  $insertStmt = $pdo->prepare("
    INSERT INTO batch_trainees (batch_id, trainee_name, training_center, status, result, created_at)
    VALUES (?, ?, ?, 'Not Yet Competent', 'Pending', NOW())
  ");

  foreach ($trainees as $t) {
    if (!is_array($t) && !is_object($t)) continue;
    $id = intval($t["id"] ?? 0);
    $name = trim((string)($t["name"] ?? ""));
    if ($name === "") continue;

    if ($id > 0) {
      $updateStmt->execute([$name, $id, $batchId]);
    } else {
      $insertStmt->execute([$batchId, $name, $trainingCenter]);
    }
  }

  $pdo->commit();
  respond("success", "Batch updated.");
} catch (Throwable $e) {
  if ($pdo && $pdo->inTransaction()) {
    $pdo->rollBack();
  }
  respond("error", "Server error: " . $e->getMessage());
}
