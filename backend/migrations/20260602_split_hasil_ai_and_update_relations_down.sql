-- Rollback Migration: revert split hasil_ai and relation changes
-- WARNING: Review before running. This attempts to restore legacy schema.

-- 1) Drop new AI tables
DROP TABLE IF EXISTS hasil_ai_gabungan;
DROP TABLE IF EXISTS hasil_ai_harian;

-- 2) Recreate legacy table hasil_ai (best-effort schema)
CREATE TABLE IF NOT EXISTS hasil_ai (
    id_hasil_ai INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT NULL,
    id_riwayat INT NULL,
    id_wearable INT NULL,
    id_hasil_lab INT NULL,
    tgl_hasil_ai DATETIME,
    score DOUBLE,
    kesimpulan_lab TEXT,
    status_harian VARCHAR(100),
    pesan_harian TEXT,
    trend_report TEXT,
    arah_perubahan VARCHAR(100),
    flag_urgensi VARCHAR(100),
    tgl_kirim DATETIME NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE,
    FOREIGN KEY (id_wearable) REFERENCES wearable(id_wearable) ON DELETE CASCADE,
    FOREIGN KEY (id_hasil_lab) REFERENCES hasil_lab(id_hasil_lab) ON DELETE SET NULL,
    FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3) Add id_user back to wearable if missing
ALTER TABLE wearable
  ADD COLUMN IF NOT EXISTS id_user INT NULL AFTER id_riwayat;

-- 4) Add id_riwayat back to hasil_lab (best-effort)
ALTER TABLE hasil_lab
  ADD COLUMN IF NOT EXISTS id_riwayat INT NULL AFTER id_hasil_lab;

-- 5) Remove id_riwayat from laporan_lab if it was added
ALTER TABLE laporan_lab
  DROP COLUMN IF EXISTS id_riwayat;

-- 6) Remove unique index on riwayat (id_user, tanggal) if present
-- Note: Some MySQL versions don't support DROP INDEX IF EXISTS; adjust manually if needed.
ALTER TABLE riwayat
  DROP INDEX IF EXISTS uq_riwayat_user_tanggal;

-- Notes:
-- This rollback is opinionated. Before running, backup data. Manual adjustments may be required to preserve data.
