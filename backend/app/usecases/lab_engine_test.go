package usecases

import (
	"testing"
	"monitoring-service/app/models" // ⚠️ Sesuaikan bagian "project/models" dengan nama module folder model asli Mas Vlen
)

func TestAnalyzeLabResults_LapisKeamananTremor(t *testing.T) {
	
	// 🟢 KASUS UJI 1: Normal Path
	t.Run("Kasus 1: Data Normal Harus Lolos", func(t *testing.T) {
		inputData := []models.AssessmentParamInput{
			{
				NamaParameter:   "TSH",
				NilaiHasil:      1.5,
				NilaiBatasBawah: 0.35,
				NilaiBatasAtas:  4.94,
			},
		}

		hasil := AnalyzeLabResults(inputData)

		// Ekspektasi: Karena data normal, interpretasi TIDAK BOLEH "Perlu Verifikasi Ulang"
		if hasil.Interpretasi == "Perlu Verifikasi Ulang" {
			t.Errorf("GAGAL: Data normal malah diblokir oleh sistem.")
		}
	})

	// 🔴 KASUS UJI 2: Tremor Desimal Path (Skip Titik Desimal akibat jari gemetar)
	t.Run("Kasus 2: Deteksi Tremor Desimal 135.0", func(t *testing.T) {
		inputData := []models.AssessmentParamInput{
			{
				NamaParameter:   "TSH",
				NilaiHasil:      135.0, // Typo ekstrem akibat tremor (harusnya 1.35)
				NilaiBatasBawah: 0.35,
				NilaiBatasAtas:  4.94,
			},
		}

		hasil := AnalyzeLabResults(inputData)

		// Ekspektasi: Logika Lapis 2 kita harus sukses mencegat dan mengeluarkan status aman
		if hasil.Interpretasi != "Perlu Verifikasi Ulang" {
			t.Errorf("GAGAL: Sistem meloloskan angka absurd 135.0 tanpa proteksi!")
		}
	})

	// 🟡 KASUS UJI 3: Batas Terbalik Path
	t.Run("Kasus 3: Deteksi Batas Acuan Terbalik", func(t *testing.T) {
		inputData := []models.AssessmentParamInput{
			{
				NamaParameter:   "TSH",
				NilaiHasil:      1.5,
				NilaiBatasBawah: 4.94, // Terbalik
				NilaiBatasAtas:  0.35, // Terbalik
			},
		}

		hasil := AnalyzeLabResults(inputData)

		// Ekspektasi: Struktur terbalik harus otomatis ditolak masuk ke inferensi medis
		if hasil.Interpretasi != "Perlu Verifikasi Ulang" {
			t.Errorf("GAGAL: Batas acuan terbalik tetap diproses secara buta.")
		}
	})
}