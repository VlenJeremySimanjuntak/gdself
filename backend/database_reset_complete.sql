-- =============================================
-- DATABASE RESET & RECREATE
-- Sesuaikan nama database sesuai project Anda
-- =============================================

-- DROP DATABASE LAMA (WARNING: DATA HILANG!)
DROP DATABASE IF EXISTS graves_disease_db;

-- BUAT DATABASE BARU
CREATE DATABASE graves_disease_db;
USE graves_disease_db;

-- =============================================
-- DATABASE SCHEMA - GRAVES DISEASE HEALTH TRACKING
-- Perbaikan: Parameter normalized ke master table
-- =============================================

-- 1. Tabel User (Utama)
CREATE TABLE user (
    id_user INT PRIMARY KEY AUTO_INCREMENT,
    nama VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    password VARCHAR(255),
    tgl_lahir DATE,
    jenis_kelamin ENUM('L', 'P'),
    tgl_terdiagnosis DATE,
    update_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. Tabel Riwayat
CREATE TABLE riwayat (
    id_riwayat INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT,
    tanggal DATE,
    FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
);

-- 3. Tabel Laporan Lab
CREATE TABLE laporan_lab (
    id_laporan_lab INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT,
    tgl_periksa DATE,
    nama_lab VARCHAR(100),
    FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
);

-- 4. Tabel Parameter (MASTER - Fixed Data)
-- Hanya 3 records: FT3, FT4, TSH
-- TIDAK punya FK ke hasil_lab (ini master data yang reusable)
CREATE TABLE parameter (
    id_parameter INT PRIMARY KEY AUTO_INCREMENT,
    nama_parameter VARCHAR(100) UNIQUE NOT NULL,
    satuan VARCHAR(20),
    kategori VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabel Hasil Lab (DETAIL - Many records)
-- Setiap hasil lab punya banyak parameter (via id_parameter FK)
CREATE TABLE hasil_lab (
    id_hasil_lab INT PRIMARY KEY AUTO_INCREMENT,
    id_laporan_lab INT,
    id_riwayat INT,
    id_parameter INT NOT NULL,
    nilai_hasil DOUBLE,
    rujukan_min DOUBLE,
    rujukan_max DOUBLE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_laporan_lab) REFERENCES laporan_lab(id_laporan_lab) ON DELETE CASCADE,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE,
    FOREIGN KEY (id_parameter) REFERENCES parameter(id_parameter) ON DELETE RESTRICT
);

-- 6. Tabel Obat
CREATE TABLE obat (
    id_obat INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT,
    nama_obat VARCHAR(100),
    dosis VARCHAR(50),
    frekuensi VARCHAR(50),
    status_aktif TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
);

-- 7. Tabel Jadwal Obat
CREATE TABLE jadwal_obat (
    id_jadwal_obat INT PRIMARY KEY AUTO_INCREMENT,
    id_obat INT,
    waktu_minum_obat VARCHAR(100), -- Bisa multiple times: "08:00, 20:00"
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_obat) REFERENCES obat(id_obat) ON DELETE CASCADE
);

-- 8. Tabel Wearable
CREATE TABLE wearable (
    id_wearable INT PRIMARY KEY AUTO_INCREMENT,
    id_riwayat INT,
    id_user INT,
    tgl_data DATE,
    waktu_data TIME,
    heart_rate_rhr INT,
    stress_score INT,
    sleep_duration INT, -- dalam menit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE,
    FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE
);

-- 9. Tabel Hasil AI
CREATE TABLE hasil_ai (
    id_hasil_ai INT PRIMARY KEY AUTO_INCREMENT,
    id_riwayat INT,
    id_wearable INT,
    id_hasil_lab INT,
    tgl_hasil_ai DATETIME,
    score DOUBLE,
    tgl_kirim DATETIME,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE,
    FOREIGN KEY (id_wearable) REFERENCES wearable(id_wearable) ON DELETE SET NULL,
    FOREIGN KEY (id_hasil_lab) REFERENCES hasil_lab(id_hasil_lab) ON DELETE SET NULL
);

-- =============================================
-- INSERT Master Data Parameter (3 records only)
-- =============================================
INSERT INTO parameter (nama_parameter, satuan, kategori) VALUES
('FT3', 'pmol/L', 'Thyroid'),
('FT4', 'pmol/L', 'Thyroid'),
('TSH', 'mIU/L', 'Thyroid');

-- =============================================
-- VERIFIKASI - Lihat hasil
-- =============================================
SELECT 'Database siap!' AS status;
SELECT * FROM parameter;
