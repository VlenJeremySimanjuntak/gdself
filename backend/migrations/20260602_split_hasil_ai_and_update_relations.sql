-- Migration: Split hasil_ai into hasil_ai_harian and hasil_ai_gabungan
-- and update wearable/laporan_lab/hasil_lab relations

-- 1) Drop legacy table hasil_ai if exists
DROP TABLE IF EXISTS hasil_ai;

-- 2) Modify wearable: drop id_user column if exists (clients no longer store id_user on wearable)
ALTER TABLE wearable
  DROP COLUMN IF EXISTS id_user;

-- 3) Modify hasil_lab: drop id_riwayat column if exists (hasil_lab now linked via laporan_lab)
ALTER TABLE hasil_lab
  DROP COLUMN IF EXISTS id_riwayat;

-- 4) Add id_riwayat to laporan_lab (link laporan_lab to riwayat)
ALTER TABLE laporan_lab
  ADD COLUMN IF NOT EXISTS id_riwayat INT NULL AFTER id_laporan_lab;

-- 5) Ensure riwayat has unique constraint on (id_user, tanggal)
ALTER TABLE riwayat
  ADD UNIQUE INDEX IF NOT EXISTS uq_riwayat_user_tanggal (id_user, tanggal);

-- 6) Create hasil_ai_harian (Machine 2: wearable daily AI)
CREATE TABLE IF NOT EXISTS hasil_ai_harian (
    id_hasil_ai_harian INT PRIMARY KEY AUTO_INCREMENT,
    id_wearable INT NOT NULL,
    id_riwayat INT NOT NULL,
    tgl_hasil_ai DATETIME,
    score DOUBLE,
    status_harian VARCHAR(100),
    pesan_harian TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_wearable) REFERENCES wearable(id_wearable) ON DELETE CASCADE,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7) Create hasil_ai_gabungan (Machine 1 & 3: lab/trend combined)
CREATE TABLE IF NOT EXISTS hasil_ai_gabungan (
    id_hasil_ai_lab INT PRIMARY KEY AUTO_INCREMENT,
    id_hasil_lab INT NULL,
    id_riwayat INT NOT NULL,
    id_wearable INT NULL,
    kesimpulan_lab TEXT,
    trend_report TEXT,
    arah_perubahan VARCHAR(100),
    tgl_hasil_ai DATETIME,
    score DOUBLE,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_hasil_lab) REFERENCES hasil_lab(id_hasil_lab) ON DELETE SET NULL,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE,
    FOREIGN KEY (id_wearable) REFERENCES wearable(id_wearable) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Notes:
-- Run this migration after ensuring backups. Some DB engines may not support IF NOT EXISTS for index/column operations.
-- Adjust NULL/NOT NULL constraints according to your data/rollback plan.
