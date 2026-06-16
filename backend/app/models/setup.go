package models

import (
	"fmt"
	"log"

	"gorm.io/gorm"
)

// SetupDatabase bertugas melakukan sinkronisasi tabel ke MySQL
func SetupDatabase(db *gorm.DB) {
	fmt.Println("Memulai sinkronisasi tabel (Auto Migration)...")

	// Eksekusi pembuatan 13 tabel secara berurutan sesuai relasi
	err := db.AutoMigrate(
		&User{},
		&Obat{},
		&JadwalObat{},
		&LogKonsumsiObat{},
		&Riwayat{},
		&Wearable{},
		&HasilAIHarian{},
		&LaporanLab{},
		&Parameter{},
		&HasilLab{},
		&USGTiroid{},
		&HasilAILab{},
		&HasilAITren{},
	)
	if err != nil {
		log.Fatal("Gagal melakukan Auto Migration:", err)
	}
	fmt.Println("Semua tabel sukses tersinkronisasi ke MySQL!")

	// Jalankan penyuntikan data awal (Seeding) untuk tabel Parameter
	seedParameter(db)
}

// seedParameter bertugas menyuntikkan data master parameter jika tabel masih kosong
func seedParameter(db *gorm.DB) {
	var count int64
	db.Model(&Parameter{}).Count(&count)

	if count == 0 {
		fmt.Println("Tabel parameter kosong. Menyuntikkan data acuan (Seeding)...")

		defaultParams := []Parameter{
			{NamaParameter: "FT3", Satuan: "pmol/L", Kategori: "Thyroid", TipeRujukan: "Standar"},
			{NamaParameter: "FT4", Satuan: "pmol/L", Kategori: "Thyroid", TipeRujukan: "Standar"},
			{NamaParameter: "TSH", Satuan: "mIU/L", Kategori: "Thyroid", TipeRujukan: "Standar"},
		}

		if err := db.Create(&defaultParams).Error; err != nil {
			fmt.Println("Gagal menyuntikkan data seeding:", err)
		} else {
			fmt.Println("Berhasil! Data FT3, FT4, dan TSH otomatis terisi.")
		}
	} else {
		fmt.Println("Data parameter acuan sudah ada, melewati proses seeding.")
	}
}