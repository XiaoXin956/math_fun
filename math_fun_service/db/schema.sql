-- math_fun_service 数据库结构
-- 完整建库建表 SQL，供 Docker 初始化或手动导入使用。
-- 后端启动时也会自动执行幂等建表，本文件为完整参考版本。

CREATE DATABASE IF NOT EXISTS math_fun CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE math_fun;

-- 用户表（家长/孩子），points 为积分
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(32) NOT NULL UNIQUE,
  password_hash VARCHAR(128) NOT NULL,
  salt VARCHAR(32) NOT NULL,
  nickname VARCHAR(32) NOT NULL,
  role ENUM('parent','child') NOT NULL DEFAULT 'child',
  grade TINYINT NULL,
  parent_id INT NULL,
  points INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 登录会话
CREATE TABLE IF NOT EXISTS sessions (
  token VARCHAR(64) PRIMARY KEY,
  user_id INT NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 题目表：type = 'math'（选择题/输入题）或 'handwriting'（手写题）
CREATE TABLE IF NOT EXISTS questions (
  id VARCHAR(64) PRIMARY KEY,
  expression VARCHAR(64) NOT NULL,
  answer INT NOT NULL,
  grade TINYINT NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'math',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 答题记录
CREATE TABLE IF NOT EXISTS records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  question_id VARCHAR(64) NOT NULL,
  expression VARCHAR(64) NOT NULL,
  answer INT NOT NULL,
  user_answer INT NOT NULL,
  correct TINYINT NOT NULL DEFAULT 0,
  mode VARCHAR(20) NOT NULL DEFAULT 'practice',
  grade TINYINT NOT NULL,
  duration_ms INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_time (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 闯关进度
CREATE TABLE IF NOT EXISTS challenge_progress (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  grade TINYINT NOT NULL,
  level TINYINT NOT NULL,
  best_correct INT NOT NULL DEFAULT 0,
  best_total INT NOT NULL DEFAULT 0,
  best_stars TINYINT NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_grade_level (user_id, grade, level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 限时挑战最佳成绩
CREATE TABLE IF NOT EXISTS timed_best (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  grade TINYINT NOT NULL,
  best_score INT NOT NULL DEFAULT 0,
  best_correct INT NOT NULL DEFAULT 0,
  played_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_grade (user_id, grade)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 积分记录（闯关奖励/扣分、退出扣分、手写批改）
CREATE TABLE IF NOT EXISTS points_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  grade TINYINT NOT NULL DEFAULT 0,
  level TINYINT NOT NULL DEFAULT 0,
  `change` INT NOT NULL,
  reason VARCHAR(128) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_time (user_id, created_at),
  INDEX idx_user_level (user_id, grade, level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 自由练习每日次数统计（每天每用户一行，用于限制每日加分次数）
CREATE TABLE IF NOT EXISTS practice_daily (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  practice_date DATE NOT NULL,
  rounds INT NOT NULL DEFAULT 0,
  UNIQUE KEY uniq_user_date (user_id, practice_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 手写答案提交（等待家长批改）
CREATE TABLE IF NOT EXISTS handwriting_submissions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  batch_id VARCHAR(64) NOT NULL,
  question_id VARCHAR(64) NOT NULL,
  expression VARCHAR(64) NOT NULL,
  answer INT NOT NULL,
  image LONGTEXT NOT NULL,
  status ENUM("pending","reviewed") NOT NULL DEFAULT "pending",
  reviewed_by INT NULL,
  review_change INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME NULL,
  INDEX idx_user (user_id),
  INDEX idx_status (status),
  INDEX idx_batch (batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
