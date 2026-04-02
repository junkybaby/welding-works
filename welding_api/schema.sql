CREATE DATABASE IF NOT EXISTS welding_works
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;

USE welding_works;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  firstname VARCHAR(80) NOT NULL,
  middlename VARCHAR(80) NULL,
  lastname VARCHAR(80) NOT NULL,
  username VARCHAR(50) NOT NULL,
  password VARCHAR(255) NOT NULL,
  email VARCHAR(120) NOT NULL,
  role VARCHAR(30) NOT NULL DEFAULT 'trainee',
  status VARCHAR(30) NOT NULL DEFAULT 'active',
  is_verified TINYINT NOT NULL DEFAULT 0,
  password_change TINYINT NOT NULL DEFAULT 0,
  verification_code VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  last_activity_at TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS batches (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  trainer_email VARCHAR(120) NOT NULL,
  trainer_username VARCHAR(50) NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  name VARCHAR(120) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_at TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_batches_user_id (user_id),
  CONSTRAINT fk_batches_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS batch_trainees (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  trainee_name VARCHAR(120) NOT NULL,
  training_center VARCHAR(120) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'Not Yet Competent',
  result VARCHAR(30) NOT NULL DEFAULT 'Pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_batch_trainees_batch_id (batch_id),
  CONSTRAINT fk_batch_trainees_batch
    FOREIGN KEY (batch_id) REFERENCES batches(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(128) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_sessions_token (token),
  KEY idx_admin_sessions_user_id (user_id),
  CONSTRAINT fk_admin_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS criteria (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  type VARCHAR(20) NOT NULL DEFAULT 'competency',
  category VARCHAR(60) NOT NULL,
  title VARCHAR(160) NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  weight_percent DECIMAL(6,2) NULL,
  scale_range VARCHAR(40) NULL,
  remark VARCHAR(80) NULL,
  active TINYINT NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_criteria_user_id (user_id),
  CONSTRAINT fk_criteria_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  actor_email VARCHAR(120) NULL,
  actor_role VARCHAR(30) NULL,
  actor_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(80) NOT NULL,
  target_type VARCHAR(40) NULL,
  target_id VARCHAR(40) NULL,
  details TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_logs_actor_user_id (actor_user_id),
  CONSTRAINT fk_audit_logs_user
    FOREIGN KEY (actor_user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (batch_trainee_id),
  CONSTRAINT fk_progress_batch_trainee
    FOREIGN KEY (batch_trainee_id) REFERENCES batch_trainees(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
