-- Migration: Add tanggal_mulai column to obat table
-- Date: 2026-05-11
-- Description: Add tanggal_mulai (start date) field to track when medication should start

ALTER TABLE obat ADD COLUMN tanggal_mulai DATE AFTER frekuensi;

-- Updated schema untuk reference:
-- CREATE TABLE obat (
--     id_obat INT PRIMARY KEY AUTO_INCREMENT,
--     id_user INT,
--     nama_obat VARCHAR(100),
--     dosis VARCHAR(50),
--     frekuensi VARCHAR(50),
--     tanggal_mulai DATE,
--     status_aktif TINYINT(1) DEFAULT 1,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
--     FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
-- );
