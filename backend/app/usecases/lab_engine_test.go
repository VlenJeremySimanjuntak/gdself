package usecases

import (
	"testing"
	"monitoring-service/app/models" 
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

		// Perbaikan: Sistem Mas Vlen mengubah StatusTSH, bukan Interpretasi
		if hasil.StatusTSH == "Perlu Verifikasi" {
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

		// Perbaikan: Sistem Mas Vlen menghasilkan "Perlu Verifikasi" di StatusTSH
		if hasil.StatusTSH != "Perlu Verifikasi" {
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

		// Perbaikan: Sistem Mas Vlen menghasilkan "Perlu Verifikasi" di StatusTSH
		if hasil.StatusTSH != "Perlu Verifikasi" {
			t.Errorf("GAGAL: Batas acuan terbalik tetap diproses secara buta.")
		}
	})
}