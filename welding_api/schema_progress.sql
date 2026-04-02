CREATE TABLE IF NOT EXISTS trainee_progress (
  batch_trainee_id BIGINT UNSIGNED NOT NULL,
  oral_status VARCHAR(30) NOT NULL DEFAULT 'pending',
  written_status VARCHAR(30) NOT NULL DEFAULT 'pending',
  demo_status VARCHAR(30) NOT NULL DEFAULT 'pending',
  oral_date_completed DATE NULL,
  written_date_completed DATE NULL,
  demo_date_completed DATE NULL,
  demo_image_url VARCHAR(255) NULL,
  demo_annotated_image_url VARCHAR(255) NULL,
  demo_label VARCHAR(120) NULL,
  demo_confidence VARCHAR(50) NULL,
  demo_reason TEXT NULL,
  demo_detections_json LONGTEXT NULL,
  performance_criteria_json LONGTEXT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (batch_trainee_id),
  CONSTRAINT fk_progress_batch_trainee
    FOREIGN KEY (batch_trainee_id) REFERENCES batch_trainees(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
