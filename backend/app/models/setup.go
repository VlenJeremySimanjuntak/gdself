package models

import (
	"fmt"
	"log"
	"strings"

	"gorm.io/gorm"
)

// SetupDatabase bertugas melakukan sinkronisasi tabel ke MySQL
func SetupDatabase(db *gorm.DB) {
	fmt.Println("Menyiapkan struktur database...")

	models := []interface{}{
		&User{}, &OTPCode{}, &Parameter{},
		&Riwayat{}, &Obat{},
		&Wearable{}, &LaporanLab{}, &USGTiroid{}, &JadwalObat{},
		&HasilLab{}, &HasilAILab{}, &HasilAITren{}, &HasilAIHarian{}, &LogKonsumsiObat{},
	}

	// 1. Membuat tabel tanpa Foreign Key (aman dari crash)
	fmt.Println("Memulai sinkronisasi tabel (Auto Migration)...")
	if err := db.AutoMigrate(models...); err != nil {
		log.Fatal("Gagal melakukan Auto Migration:", err)
	}

	// 2. Memasang garis relasi secara manual ke database
	fmt.Println("Memasang garis relasi (Foreign Key) untuk ERD...")
	addForeignKeys(db)

	fmt.Println("Semua tabel sukses tersinkronisasi ke MySQL dengan Foreign Key yang utuh!")

	seedParameter(db)
}

// addForeignKeys mengeksekusi raw SQL untuk mengikat tabel-tabel
func addForeignKeys(db *gorm.DB) {
	// Matikan sementara pengecekan saat memasang kunci
	db.Exec("SET FOREIGN_KEY_CHECKS = 0;")

	// Daftar relasi (garis) yang akan dibentuk di ERD
	fkQueries := []string{
		// User -> Riwayat & Obat
		"ALTER TABLE riwayat ADD CONSTRAINT fk_riwayat_user FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE ON UPDATE CASCADE;",
		"ALTER TABLE obat ADD CONSTRAINT fk_obat_user FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Obat -> Jadwal
		"ALTER TABLE jadwal_obat ADD CONSTRAINT fk_jadwal_obat FOREIGN KEY (id_obat) REFERENCES obat(id_obat) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Jadwal -> Log Konsumsi
		"ALTER TABLE log_konsumsi_obat ADD CONSTRAINT fk_log_jadwal FOREIGN KEY (id_jadwal_obat) REFERENCES jadwal_obat(id_jadwal_obat) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Riwayat -> Wearable, Laporan Lab, USG
		"ALTER TABLE wearable ADD CONSTRAINT fk_wearable_riwayat FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE ON UPDATE CASCADE;",
		"ALTER TABLE laporan_lab ADD CONSTRAINT fk_laporan_riwayat FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE ON UPDATE CASCADE;",
		"ALTER TABLE usg_tiroid ADD CONSTRAINT fk_usg_riwayat FOREIGN KEY (id_riwayat) REFERENCES riwayat(id_riwayat) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Wearable -> Hasil AI Harian
		"ALTER TABLE hasil_ai_harian ADD CONSTRAINT fk_harian_wearable FOREIGN KEY (id_wearable) REFERENCES wearable(id_wearable) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Laporan Lab -> Hasil Lab, AI Lab, AI Tren
		"ALTER TABLE hasil_lab ADD CONSTRAINT fk_hasil_laporan FOREIGN KEY (id_laporan_lab) REFERENCES laporan_lab(id_laporan_lab) ON DELETE CASCADE ON UPDATE CASCADE;",
		"ALTER TABLE hasil_ai_lab ADD CONSTRAINT fk_ai_lab_laporan FOREIGN KEY (id_laporan_lab) REFERENCES laporan_lab(id_laporan_lab) ON DELETE CASCADE ON UPDATE CASCADE;",
		"ALTER TABLE hasil_ai_tren ADD CONSTRAINT fk_ai_tren_laporan FOREIGN KEY (id_laporan_lab) REFERENCES laporan_lab(id_laporan_lab) ON DELETE CASCADE ON UPDATE CASCADE;",

		// Parameter -> Hasil Lab
		"ALTER TABLE hasil_lab ADD CONSTRAINT fk_hasil_parameter FOREIGN KEY (id_parameter) REFERENCES parameter(id_parameter) ON DELETE RESTRICT ON UPDATE CASCADE;",
	}

	// Eksekusi satu per satu
	for _, query := range fkQueries {
		err := db.Exec(query).Error
		// Kita abaikan error "Duplicate key" jika garisnya memang sudah pernah dibuat sebelumnya
		if err != nil && !strings.Contains(err.Error(), "Duplicate key") {
			// Hanya tampilkan di log jika errornya bukan karena duplikat
			log.Println("Peringatan saat membuat FK:", err)
		}
	}

	// Nyalakan kembali aturan ketat MySQL
	db.Exec("SET FOREIGN_KEY_CHECKS = 1;")
}

// seedParameter bertugas menyuntikkan data master parameter jika tabel masih kosong
func seedParameter(db *gorm.DB) {
	var count int64
	db.Model(&Parameter{}).Count(&count)

	if count == 0 {
		fmt.Println("Tabel parameter kosong. Menyuntikkan data acuan (Seeding)...")

		defaultParams := []Parameter{
			{NamaParameter: "FT3", Satuan: "pmol/L", Kategori: "Thyroid", TipeRujukan: "range"},
			{NamaParameter: "FT4", Satuan: "pmol/L", Kategori: "Thyroid", TipeRujukan: "range"},
			{NamaParameter: "TSHs", Satuan: "mIU/L", Kategori: "Thyroid", TipeRujukan: "range"},
			{NamaParameter: "TRAb", Satuan: "IU/L", Kategori: "Thyroid", TipeRujukan: "treshold"},
		}

		if err := db.Create(&defaultParams).Error; err != nil {
			fmt.Println("Gagal menyuntikkan data seeding:", err)
		} else {
			fmt.Println("Berhasil! Data FT3, FT4, dan TSHs otomatis terisi.")
		}
	} else {
		fmt.Println("Data parameter acuan sudah ada, melewati proses seeding.")
	}
}