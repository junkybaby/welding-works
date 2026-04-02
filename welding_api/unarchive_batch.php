<?php
require_once __DIR__ . "/db.php";

$data = read_json();
$batchId = intval($data["batch_id"] ?? 0);

if ($batchId <= 0) {
  respond("error", "Batch id is required.");
}

try {
  $pdo = db();
  $stmt = $pdo->prepare("
    UPDATE batches
    SET status = 'active', archived_at = NULL
    WHERE id = ?
  ");
  $stmt->execute([$batchId]);

  respond("success", "Batch restored.");
} catch (Throwable $e) {
  respond("error", "Server error: " . $e->getMessage());
}
