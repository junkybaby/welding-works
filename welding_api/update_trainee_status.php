<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$traineeId = intval($data["batch_trainee_id"] ?? 0);
$status = trim($data["status"] ?? "");
$result = trim($data["result"] ?? "");

if ($traineeId <= 0 || $status === "" || $result === "") {
  respond("error", "Missing required fields.");
}

$allowedStatus = ["Competent", "Not Yet Competent"];
$allowedResult = ["Pending", "Assessed", "For Re-assessment"];

if (!in_array($status, $allowedStatus, true)) {
  respond("error", "Invalid status.");
}

if (!in_array($result, $allowedResult, true)) {
  respond("error", "Invalid result.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    UPDATE batch_trainees
    SET status = ?, result = ?
    WHERE id = ?
  ");
  $stmt->execute([$status, $result, $traineeId]);
  respond("success", "Updated.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
