package usecases

import (
	"fmt"
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
	if p.NilaiHasil == 0 {
		return "", ""
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
	if p.NilaiHasil == 0 {
		return "", ""
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
	if p.NilaiHasil == 0 {
		return "", ""
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
	if p.NilaiHasil == 0 {
		return "", ""
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
	isFT3Aman := statusFT3 == "Normal" || statusFT3 == ""
	isFT4Aman := statusFT4 == "Normal" || statusFT4 == ""

	isFT3TinggiAtauAman := statusFT3 == "Tinggi" || statusFT3 == "Normal" || statusFT3 == ""
	isFT4TinggiAtauAman := statusFT4 == "Tinggi" || statusFT4 == "Normal" || statusFT4 == ""

	// Aturan 1: TSH Normal + FT3 Normal/Kosong + FT4 Normal/Kosong → Normal
	if statusTSH == "Normal" && isFT3Aman && isFT4Aman {
		return "Normal"
	}

	// Aturan 2-5: TSH Rendah + FT3 (Tinggi/Normal/Kosong) + FT4 (Tinggi/Normal/Kosong) → Belum Normal
	if statusTSH == "Rendah" && isFT3TinggiAtauAman && isFT4TinggiAtauAman {
		return "Belum Normal"
	}

	// Selain aturan di atas / Jika tidak sesuai pola → Tidak Terinterpretasi
	return "Pola Hormon Belum Sesuai Graves Disease"
}

// ==========================================
// VALIDASI ANTI-TREMOR PER PARAMETER
// ==========================================
const paramPerluVerifikasi = "Perlu Verifikasi"
const paramPerluVerifikasiPesan = "Nilai yang dimasukkan tampak berada jauh di luar rentang yang wajar secara medis. Mohon periksa kembali angka yang diketik, terutama jika kondisi fisik sedang kurang stabil."

// isNilaiMencurigakan mengecek 1 parameter: apakah nilainya kemungkinan besar salah ketik
func isNilaiMencurigakan(p models.AssessmentParamInput) bool {
	// Kalau belum diisi sama sekali, itu bukan kasus "mencurigakan" — itu memang kosong
	if p.NilaiHasil == 0 {
		return false
	}

	// A. Rentang batas terbalik (batas bawah >= batas atas)
	if p.NilaiBatasBawah > 0 && p.NilaiBatasAtas > 0 && p.NilaiBatasBawah >= p.NilaiBatasAtas {
		return true
	}

	// B. Nilai hasil jauh melampaui batas atas (>10x lipat)
	if p.NilaiBatasAtas > 0 && p.NilaiHasil > (p.NilaiBatasAtas*10.0) {
		return true
	}

	return false
}

func AnalyzeLabResults(params []models.AssessmentParamInput) LabAssessmentResult {
	var result LabAssessmentResult
	paramMap := extractHormoneValues(params)

	// ===== TSH =====
	if tsh, ok := paramMap["TSH"]; ok {
		if isNilaiMencurigakan(tsh) {
			result.StatusTSH = paramPerluVerifikasi
			result.ReminderTSH = fmt.Sprintf("TSHs: %s", paramPerluVerifikasiPesan)
			result.NilaiTSH = tsh.NilaiHasil // tetap simpan nilai mentah untuk audit
		} else {
			result.StatusTSH, result.ReminderTSH = evaluateTSH(tsh)
			result.NilaiTSH = tsh.NilaiHasil
		}
	}

	// ===== FT4 =====
	if ft4, ok := paramMap["FT4"]; ok {
		if isNilaiMencurigakan(ft4) {
			result.StatusFT4 = paramPerluVerifikasi
			result.ReminderFT4 = fmt.Sprintf("FT4: %s", paramPerluVerifikasiPesan)
			result.NilaiFT4 = ft4.NilaiHasil
		} else {
			result.StatusFT4, result.ReminderFT4 = evaluateFT4(ft4)
			result.NilaiFT4 = ft4.NilaiHasil
		}
	}

	// ===== FT3 =====
	if ft3, ok := paramMap["FT3"]; ok {
		if isNilaiMencurigakan(ft3) {
			result.StatusFT3 = paramPerluVerifikasi
			result.ReminderFT3 = fmt.Sprintf("FT3: %s", paramPerluVerifikasiPesan)
			result.NilaiFT3 = ft3.NilaiHasil
		} else {
			result.StatusFT3, result.ReminderFT3 = evaluateFT3(ft3)
			result.NilaiFT3 = ft3.NilaiHasil
		}
	}

	// ===== TRAb =====
	if trab, ok := paramMap["TRAB"]; ok {
		if isNilaiMencurigakan(trab) {
			result.StatusTRAb = paramPerluVerifikasi
			result.ReminderTRAb = fmt.Sprintf("TRAb: %s", paramPerluVerifikasiPesan)
			result.NilaiTRAb = trab.NilaiHasil
		} else {
			result.StatusTRAb, result.ReminderTRAb = evaluateTRAb(trab)
			result.NilaiTRAb = trab.NilaiHasil
		}
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
	if prevNilai == 0 || currNilai == 0 {
		return "-", "-"
	}

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

	// Di luar pola terdaftar
	return "-", "-"
}

func trenFT3(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
	if prevNilai == 0 || currNilai == 0 {
		return "-", "-"
	}

	// -------------------------------------------------------------
	// JALUR TRANSISI 
	// -------------------------------------------------------------
	// Pemulihan dari Tinggi ke Normal
	if prevStatus == "Tinggi" && currStatus == "Normal" {
		return "Mendekati normal", "FT3 anda telah mencapai rentang normal. Tren menunjukkan perbaikan yang sangat baik dari kondisi sebelumnya."
	}
	// Memburuk dari Normal
	if prevStatus == "Normal" && currStatus != "Normal" {
		return "Menjauhi normal", "FT3 anda keluar dari rentang normal dibandingkan pemeriksaan sebelumnya. Harap konsultasikan dengan dokter."
	}

	// -------------------------------------------------------------
	// JALUR 1: STATUS TETAP NORMAL
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
	return "-", "-"
}

func trenFT4(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
	if prevNilai == 0 || currNilai == 0 {
		return "-", "-"
	}

	// -------------------------------------------------------------
	// JALUR TRANSISI
	// -------------------------------------------------------------
	// Pemulihan dari Tinggi ke Normal
	if prevStatus == "Tinggi" && currStatus == "Normal" {
		return "Mendekati normal", "FT4 anda telah mencapai rentang normal. Tren menunjukkan perbaikan yang sangat baik dari kondisi sebelumnya."
	}
	// Memburuk dari Normal
	if prevStatus == "Normal" && currStatus != "Normal" {
		return "Menjauhi normal", "FT4 anda keluar dari rentang normal dibandingkan pemeriksaan sebelumnya. Harap konsultasikan dengan dokter."
	}

	// -------------------------------------------------------------
	// JALUR 1: STATUS TETAP NORMAL
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
	return "-", "-"
}

func trenTRAb(prevNilai, currNilai float64, prevStatus, currStatus string) (tren, reminder string) {
	if prevNilai == 0 || currNilai == 0 {
		return "-", "-"
	}

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

	return "-", "-"
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
	tren.TrenTSH, tren.ReminderTrenTSH = trenTSH(prev.NilaiTSH, curr.NilaiTSH, prev.StatusTSH, curr.StatusTSH)
	tren.TrenFT3, tren.ReminderTrenFT3 = trenFT3(prev.NilaiFT3, curr.NilaiFT3, prev.StatusFT3, curr.StatusFT3)
	tren.TrenFT4, tren.ReminderTrenFT4 = trenFT4(prev.NilaiFT4, curr.NilaiFT4, prev.StatusFT4, curr.StatusFT4)
	tren.TrenTRAb, tren.ReminderTrenTRAb = trenTRAb(prev.NilaiTRAb, curr.NilaiTRAb, prev.StatusTRAb, curr.StatusTRAb)
	return tren
}