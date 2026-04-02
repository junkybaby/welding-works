<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$trainerEmail = strtolower(trim($data["trainer_email"] ?? ""));
$trainerUsername = trim($data["trainer_username"] ?? "");
$name = trim($data["name"] ?? "");
$trainingCenter = trim($data["training_center"] ?? "");
$trainees = $data["trainees"] ?? [];

if ($trainerEmail === "" || $trainerUsername === "" || $name === "" || $trainingCenter === "") {
  respond("error", "Missing required fields.");
}

if (!is_array($trainees) || count($trainees) === 0) {
  respond("error", "Add at least one trainee.");
}

try {
  $pdo = db();
  $pdo->beginTransaction();

  $stmt = $pdo->prepare("
    INSERT INTO batches (trainer_email, trainer_username, user_id, name, status, created_at)
    VALUES (?, ?, ?, ?, 'active', NOW())
  ");
  $userStmt = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
  $userStmt->execute([$trainerEmail]);
  $userId = $userStmt->fetchColumn() ?: null;
  $stmt->execute([$trainerEmail, $trainerUsername, $userId, $name]);
  $batchId = $pdo->lastInsertId();

  $tstmt = $pdo->prepare("
    INSERT INTO batch_trainees (batch_id, trainee_name, training_center, status, result, created_at)
    VALUES (?, ?, ?, 'Not Yet Competent', 'Pending', NOW())
  ");

  $inserted = 0;
  foreach ($trainees as $traineeName) {
    $clean = trim((string)$traineeName);
    if ($clean === "") continue;
    $tstmt->execute([$batchId, $clean, $trainingCenter]);
    $inserted++;
  }

  if ($inserted === 0) {
    $pdo->rollBack();
    respond("error", "Add at least one trainee.");
  }

  $pdo->commit();
  respond("success", "Batch created.", ["batch_id" => $batchId]);
} catch (Throwable $e) {
  if ($pdo && $pdo->inTransaction()) {
    $pdo->rollBack();
  }
  respond("error", "Server error: " . $e->getMessage());
}
