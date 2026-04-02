ALTER TABLE trainee_progress
  ADD COLUMN demo_image_url VARCHAR(255) NULL,
  ADD COLUMN demo_annotated_image_url VARCHAR(255) NULL;

ALTER TABLE trainee_progress
  ADD COLUMN performance_criteria_json LONGTEXT NULL;

ALTER TABLE trainee_progress
  ADD COLUMN demo_label VARCHAR(120) NULL,
  ADD COLUMN demo_confidence VARCHAR(50) NULL,
  ADD COLUMN demo_reason TEXT NULL,
  ADD COLUMN demo_detections_json LONGTEXT NULL;
