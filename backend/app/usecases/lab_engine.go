package usecases

import (
	"fmt"
	"strings"

	"monitoring-service/app/models"
)

// ==========================================
// HASIL ANALISIS LAB
// ==========================================
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

	// Nilai mentah untuk keperluan analisis tren
	NilaiTSH  float64
	NilaiFT3  float64
	NilaiFT4  float64
	NilaiTRAb float64
}

// ==========================================
// EKSTRAK NILAI HORMON DARI PARAMETER INPUT
// ==========================================
func extractHormoneValues(params []models.AssessmentParamInput) map[string]models.AssessmentParamInput {
	result := make(map[string]models.AssessmentParamInput)
	for _, p := range params {
		key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		// Normalisasi nama parameter
		if key == "TSHS" || key == "TSH" {
			key = "TSH"
		}
		result[key] = p
	}
	return result
}

// ==========================================
// EVALUASI INDIVIDUAL PER PARAMETER
// ==========================================

// TSHs: Rendah / Normal / Tinggi / Tidak Diketahui
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

// FT3: Rendah / Normal / Tinggi / Tidak Diketahui
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

// FT4: Rendah / Normal / Tinggi / Tidak Diketahui
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

// TRAb: Negatif / Positif / Tidak Diketahui
// TRAb dianggap Positif jika nilai > batas atas (cutoff)
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
// INTERPRETASI KESELURUHAN (TABEL KOMBINASI)
// ==========================================
func interpretasiKeseluruhan(statusTSH, statusFT3, statusFT4, statusTRAb string) string {
	// Normal: TSH Normal + FT4 Normal + TRAb Negatif (FT3 diabaikan)
	if statusTSH == "Normal" && statusFT4 == "Normal" && statusTRAb == "Negatif" {
		return "Normal"
	}

	// Belum Normal: TSH Rendah + TRAb Positif + (FT4 Tinggi atau FT3 Tinggi atau keduanya)
	if statusTSH == "Rendah" && statusTRAb == "Positif" {
		if statusFT4 == "Tinggi" || statusFT3 == "Tinggi" {
			return "Belum Normal"
		}
		// TSH Rendah + TRAb Positif + FT4 Normal + FT3 Tidak Diketahui → Belum Normal
		if statusFT4 == "Normal" && (statusFT3 == "Tidak Diketahui" || statusFT3 == "Normal") {
			return "Belum Normal"
		}
	}

	return "Tidak Diketahui"
}

// ==========================================
// ANALISIS TREN PER PARAMETER
// ==========================================

// Tren TSHs: status Rendah/Normal/Tinggi + perubahan nilai
func trenTSH(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Tinggi":
		return "Tidak Diketahui",
			"Kondisi TSHs saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	case "Normal":
		return "Tetap Normal",
			fmt.Sprintf("Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal dibandingkan sebelumnya. Nilai TSHs %s dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal.", arahPerubahan(prevNilai, currNilai))
	case "Rendah":
		switch {
		case currNilai > prevNilai:
			return "Mendekati Normal",
				"Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		case currNilai < prevNilai:
			return "Menjauhi Normal",
				"Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		default:
			return "Tidak Berubah",
				"Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal. Nilai TSHs tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di bawah rentang normal dan belum menunjukkan perubahan menuju rentang normal."
		}
	default:
		return "Tidak Diketahui",
			"Kondisi TSHs saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

// Tren FT3: status Tinggi/Normal/Rendah + perubahan nilai
func trenFT3(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Rendah":
		return "Tidak Diketahui",
			"Kondisi FT3 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	case "Normal":
		return "Tetap Normal",
			fmt.Sprintf("Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi %s nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal.", arahPerubahan(prevNilai, currNilai))
	case "Tinggi":
		switch {
		case currNilai > prevNilai:
			return "Menjauhi Normal",
				"Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		case currNilai < prevNilai:
			return "Mendekati Normal",
				"Berdasarkan hasil pemeriksaan, FT3 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		default:
			return "Tidak Berubah",
				"Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal. Nilai FT3 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
		}
	default:
		return "Tidak Diketahui",
			"Kondisi FT3 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

// Tren FT4: sama dengan FT3
func trenFT4(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Rendah":
		return "Tidak Diketahui",
			"Kondisi FT4 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	case "Normal":
		return "Tetap Normal",
			fmt.Sprintf("Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi %s nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal.", arahPerubahan(prevNilai, currNilai))
	case "Tinggi":
		switch {
		case currNilai > prevNilai:
			return "Menjauhi Normal",
				"Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		case currNilai < prevNilai:
			return "Mendekati Normal",
				"Berdasarkan hasil pemeriksaan, FT4 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		default:
			return "Tidak Berubah",
				"Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal. Nilai FT4 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
		}
	default:
		return "Tidak Diketahui",
			"Kondisi FT4 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

// Tren TRAb: Negatif/Positif + perubahan nilai
func trenTRAb(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Negatif":
		return "Tetap Normal",
			fmt.Sprintf("Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun tiroid (negatif) dibandingkan sebelumnya. Terjadi %s nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam kategori negatif.", arahPerubahan(prevNilai, currNilai))
	case "Positif":
		switch {
		case currNilai > prevNilai:
			return "Menjauhi Normal",
				"Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun tiroid (positif) dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi kategori negatif."
		case currNilai < prevNilai:
			return "Mendekati Normal",
				"Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun tiroid (positif) dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati kategori negatif."
		default:
			return "Tidak Berubah",
				"Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun tiroid (positif). Nilai TRAb tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada dalam kategori positif."
		}
	default:
		return "Tidak Diketahui",
			"Kondisi TRAb saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

// Helper: arah perubahan nilai untuk teks reminder
func arahPerubahan(prev, curr float64) string {
	if curr > prev {
		return "peningkatan"
	}
	if curr < prev {
		return "penurunan"
	}
	return "tidak ada perubahan"
}

// ==========================================
// FUNGSI UTAMA ANALISIS LAB
// ==========================================
func AnalyzeLabResults(params []models.AssessmentParamInput) LabAssessmentResult {
	var result LabAssessmentResult
	paramMap := extractHormoneValues(params)

	// Evaluasi TSH (wajib)
	if tsh, ok := paramMap["TSH"]; ok {
		result.StatusTSH, result.ReminderTSH = evaluateTSH(tsh)
		result.NilaiTSH = tsh.NilaiHasil
	} else {
		result.StatusTSH = "Tidak Diketahui"
		result.ReminderTSH = "Hasil pemeriksaan TSHs tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	// Evaluasi FT4 (wajib)
	if ft4, ok := paramMap["FT4"]; ok {
		result.StatusFT4, result.ReminderFT4 = evaluateFT4(ft4)
		result.NilaiFT4 = ft4.NilaiHasil
	} else {
		result.StatusFT4 = "Tidak Diketahui"
		result.ReminderFT4 = "Hasil pemeriksaan FT4 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	// Evaluasi FT3 (opsional)
	if ft3, ok := paramMap["FT3"]; ok {
		result.StatusFT3, result.ReminderFT3 = evaluateFT3(ft3)
		result.NilaiFT3 = ft3.NilaiHasil
	} else {
		result.StatusFT3 = "Tidak Diketahui"
		result.ReminderFT3 = "Hasil pemeriksaan FT3 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	// Evaluasi TRAb (opsional)
	if trab, ok := paramMap["TRAB"]; ok {
		result.StatusTRAb, result.ReminderTRAb = evaluateTRAb(trab)
		result.NilaiTRAb = trab.NilaiHasil
	} else {
		result.StatusTRAb = "Tidak Diketahui"
		result.ReminderTRAb = "Hasil pemeriksaan TRAb tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	// Interpretasi keseluruhan
	result.Interpretasi = interpretasiKeseluruhan(
		result.StatusTSH,
		result.StatusFT3,
		result.StatusFT4,
		result.StatusTRAb,
	)

	return result
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

	tren.TrenTSH, tren.ReminderTrenTSH = trenTSH(prev.NilaiTSH, curr.NilaiTSH, curr.StatusTSH)
	tren.TrenFT3, tren.ReminderTrenFT3 = trenFT3(prev.NilaiFT3, curr.NilaiFT3, curr.StatusFT3)
	tren.TrenFT4, tren.ReminderTrenFT4 = trenFT4(prev.NilaiFT4, curr.NilaiFT4, curr.StatusFT4)
	tren.TrenTRAb, tren.ReminderTrenTRAb = trenTRAb(prev.NilaiTRAb, curr.NilaiTRAb, curr.StatusTRAb)

	return tren
}