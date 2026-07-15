package usecases

import (
	"strings"

	"monitoring-service/app/models"
)

type LabAssessmentResult struct {
	StatusTSH    string
	ReminderTSH  string
	StatusFT3    string
	ReminderFT3  string
	StatusFT4    string
	ReminderFT4  string
	StatusTRAb   string
	ReminderTRAb string
	Interpretasi string

	NilaiTSH  float64
	NilaiFT3  float64
	NilaiFT4  float64
	NilaiTRAb float64
}

func extractHormoneValues(params []models.AssessmentParamInput) map[string]models.AssessmentParamInput {
	result := make(map[string]models.AssessmentParamInput)
	for _, p := range params {
		key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		if key == "TSHS" || key == "TSH" {
			key = "TSH"
		}
		result[key] = p
	}
	return result
}

// ==========================================
// EVALUASI PER PARAMETER
// ==========================================

func evaluateTSH(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan TSHs tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa TSHs berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa TSHs berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa TSHs berada dalam rentang yang diharapkan."
}

func evaluateFT3(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan FT3 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa FT3 berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa FT3 berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa FT3 berada dalam rentang yang diharapkan."
}

func evaluateFT4(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan FT4 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa FT4 berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa FT4 berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa FT4 berada dalam rentang yang diharapkan."
}

func evaluateTRAb(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan TRAb tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Positif",
			"Hasil pemeriksaan menunjukkan adanya penanda autoimun tiroid (TRAb positif)."
	}
	return "Negatif",
		"Hasil pemeriksaan menunjukkan tidak adanya penanda autoimun tiroid (TRAb negatif)."
}

// ==========================================
// FUNGSI INTERPRETASI KESELURUHAN (Sesuai Tabel Skripsi)
// ==========================================
func interpretasiKeseluruhan(statusTSH, statusFT3, statusFT4 string) string {
	isFT3Aman := statusFT3 == "Normal" || statusFT3 == "Tidak Diketahui"
	isFT4Aman := statusFT4 == "Normal" || statusFT4 == "Tidak Diketahui"

	isFT3TinggiAtauAman := statusFT3 == "Tinggi" || statusFT3 == "Normal" || statusFT3 == "Tidak Diketahui"
	isFT4TinggiAtauAman := statusFT4 == "Tinggi" || statusFT4 == "Normal" || statusFT4 == "Tidak Diketahui"

	// Aturan 1: TSH Normal + FT3 Normal/TidakDiketahui + FT4 Normal/TidakDiketahui → Normal
	if statusTSH == "Normal" && isFT3Aman && isFT4Aman {
		return "Normal"
	}

	// Aturan 2-5: TSH Rendah + FT3 (Tinggi/Normal/TidakDiketahui) + FT4 (Tinggi/Normal/TidakDiketahui) → Belum Normal
	if statusTSH == "Rendah" && isFT3TinggiAtauAman && isFT4TinggiAtauAman {
		return "Belum Normal"
	}

	// Selain aturan di atas → Tidak Terinterpretasi
	return "Tidak Terinterpretasi"
}

func AnalyzeLabResults(params []models.AssessmentParamInput) LabAssessmentResult {
	var result LabAssessmentResult
	paramMap := extractHormoneValues(params)

	// =========================================================================
	// 🛑 INJEKSI LOGIKA LAPIS 2: VALIDASI RELATIF (ANTI-TREMOR)
	// Hanya mengubah logika internal tanpa mengubah struktur data/model sama sekali
	// =========================================================================
	for _, key := range []string{"TSH", "FT4", "FT3"} {
		if p, ok := paramMap[key]; ok {
			// A. Logika Struktur: Cek rentang terbalik
			if p.NilaiBatasBawah >= p.NilaiBatasAtas {
				result.Interpretasi = "Perlu Verifikasi Ulang"
				return result
			}

			// B. Logika Magnitudo: Turunkan pengali menjadi 10.0 agar lebih sensitif
			if p.NilaiBatasAtas > 0 && p.NilaiHasil > (p.NilaiBatasAtas*10.0) { // 👈 UBAH DI SINI
				result.Interpretasi = "Perlu Verifikasi Ulang"
				return result
			}
		}
	}
	// =========================================================================

	// ── LOGIKA ASLI MAS VLEN TETAP BERJALAN DI BAWAH SINI TANPA BERUBAH ──
	if tsh, ok := paramMap["TSH"]; ok {
		result.StatusTSH, result.ReminderTSH = evaluateTSH(tsh)
		result.NilaiTSH = tsh.NilaiHasil
	} else {
		result.StatusTSH = "Tidak Diketahui"
		result.ReminderTSH = "Hasil pemeriksaan TSHs tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if ft4, ok := paramMap["FT4"]; ok {
		result.StatusFT4, result.ReminderFT4 = evaluateFT4(ft4)
		result.NilaiFT4 = ft4.NilaiHasil
	} else {
		result.StatusFT4 = "Tidak Diketahui"
		result.ReminderFT4 = "Hasil pemeriksaan FT4 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if ft3, ok := paramMap["FT3"]; ok {
		result.StatusFT3, result.ReminderFT3 = evaluateFT3(ft3)
		result.NilaiFT3 = ft3.NilaiHasil
	} else {
		result.StatusFT3 = "Tidak Diketahui"
		result.ReminderFT3 = "Hasil pemeriksaan FT3 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if trab, ok := paramMap["TRAB"]; ok {
		result.StatusTRAb, result.ReminderTRAb = evaluateTRAb(trab)
		result.NilaiTRAb = trab.NilaiHasil
	} else {
		result.StatusTRAb = "Tidak Diketahui"
		result.ReminderTRAb = "Hasil pemeriksaan TRAb tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	result.Interpretasi = interpretasiKeseluruhan(
		result.StatusTSH,
		result.StatusFT3,
		result.StatusFT4,
	)

	return result
}

// ==========================================
// ANALISIS TREN PER PARAMETER DENGAN TRANSISI STATUS
// ==========================================

func trenTSH(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
	// Pemulihan dari Rendah ke Normal
	if prevStatus == "Rendah" && currStatus == "Normal" {
		return "Mendekati normal", "TSHs anda telah mencapai rentang normal. Tren menunjukkan perbaikan yang sangat baik dari kondisi sebelumnya."
	}

	// Memburuk dari Normal
	if prevStatus == "Normal" && currStatus != "Normal" {
		return "Menjauhi normal", "TSHs anda keluar dari rentang normal dibandingkan pemeriksaan sebelumnya. Harap konsultasikan dengan dokter."
	}

	// Tetap Normal — dibedakan naik/turun/tetap
	if prevStatus == "Normal" && currStatus == "Normal" {
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		}
		return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal. Nilai TSHs tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
	}

	// Masih Rendah
	if currStatus == "Rendah" {
		if currNilai > prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		} else if currNilai < prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		}
		return "Tidak berubah", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal. Nilai TSHs tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di bawah rentang normal dan belum menunjukkan perubahan menuju rentang normal."
	}

	// Tinggi → Tidak diketahui (sesuai Tabel 4.23)
	return "Tidak diketahui", "Kondisi TSHs saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
}

func trenFT3(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
    // -------------------------------------------------------------
    // JALUR 1: STATUS SAAT INI NORMAL (Hasil selalu Tetap Normal)
    // -------------------------------------------------------------
    if currStatus == "Normal" {
        if currNilai > prevNilai {
            return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
        } else if currNilai < prevNilai {
            return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
        }
        return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal. Nilai FT3 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
    }

    // -------------------------------------------------------------
    // JALUR 2: STATUS SAAT INI TINGGI
    // -------------------------------------------------------------
    if currStatus == "Tinggi" {
        if currNilai > prevNilai {
            return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
        } else if currNilai < prevNilai {
            return "Mendekati normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
        }
        return "Tidak berubah", "Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal. Nilai FT3 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
    }

    // -------------------------------------------------------------
    // JALUR 3: STATUS SAAT INI RENDAH / DI LUAR POLA
    // -------------------------------------------------------------
    return "Tidak diketahui", "Kondisi FT3 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
}

func trenFT4(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
    // -------------------------------------------------------------
    // JALUR 1: STATUS SAAT INI NORMAL (Hasil selalu Tetap Normal)
    // -------------------------------------------------------------
    if currStatus == "Normal" {
        if currNilai > prevNilai {
            return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
        } else if currNilai < prevNilai {
            return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
        }
        return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal. Nilai FT4 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
    }

    // -------------------------------------------------------------
    // JALUR 2: STATUS SAAT INI TINGGI
    // -------------------------------------------------------------
    if currStatus == "Tinggi" {
        if currNilai > prevNilai {
            return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
        } else if currNilai < prevNilai {
            return "Mendekati normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
        }
        return "Tidak berubah", "Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal. Nilai FT4 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
    }

    // -------------------------------------------------------------
    // JALUR 3: STATUS SAAT INI RENDAH / DI LUAR POLA
    // -------------------------------------------------------------
    return "Tidak diketahui", "Kondisi FT4 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
}

func trenTRAb(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
	// Pemulihan dari Positif ke Negatif
	if prevStatus == "Positif" && currStatus == "Negatif" {
		return "Mendekati normal", "TRAb anda telah mencapai rentang negatif (normal). Tren menunjukkan perbaikan yang sangat baik dari kondisi sebelumnya."
	}

	// Memburuk dari Negatif ke Positif
	if prevStatus == "Negatif" && currStatus == "Positif" {
		return "Menjauhi normal", "TRAb anda berubah menjadi Positif. Harap konsultasikan dengan dokter terkait hasil ini."
	}

	// Tetap Negatif — dibedakan naik/turun/tetap
	if prevStatus == "Negatif" && currStatus == "Negatif" {
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif) dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam kategori negatif."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif) dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam kategori negatif."
		}
		return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif). Nilai TRAb tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam kategori negatif."
	}

	// Masih Positif — dibedakan naik/turun/tetap
	if currStatus == "Positif" {
		if currNilai > prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif) dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi kategori negatif."
		} else if currNilai < prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif) dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati kategori negatif."
		}
		return "Tidak berubah", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif). Nilai TRAb tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada dalam kategori positif."
	}

	return "Tidak diketahui", "Kondisi TRAb saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
}

// ==========================================
// FUNGSI ANALISIS TREN (MESIN 3)
// ==========================================
type TrenResult struct {
	TrenTSH          string
	ReminderTrenTSH  string
	TrenFT3          string
	ReminderTrenFT3  string
	TrenFT4          string
	ReminderTrenFT4  string
	TrenTRAb         string
	ReminderTrenTRAb string
}

func AnalyzeTren(prev, curr LabAssessmentResult) TrenResult {
	var tren TrenResult
	// ✅ SEKARANG FUNGSI MEMINTA 4 PARAMETER: Nilai Lama, Nilai Baru, Status Lama, Status Baru
	tren.TrenTSH, tren.ReminderTrenTSH = trenTSH(prev.NilaiTSH, curr.NilaiTSH, prev.StatusTSH, curr.StatusTSH)
	tren.TrenFT3, tren.ReminderTrenFT3 = trenFT3(prev.NilaiFT3, curr.NilaiFT3, prev.StatusFT3, curr.StatusFT3)
	tren.TrenFT4, tren.ReminderTrenFT4 = trenFT4(prev.NilaiFT4, curr.NilaiFT4, prev.StatusFT4, curr.StatusFT4)
	tren.TrenTRAb, tren.ReminderTrenTRAb = trenTRAb(prev.NilaiTRAb, curr.NilaiTRAb, prev.StatusTRAb, curr.StatusTRAb)
	return tren
}
