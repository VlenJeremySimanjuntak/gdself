 package usecases

import (
	"testing"
	"monitoring-service/app/models"
)

// ==========================================
// ✅ HELPER: Buat input parameter (Di-rename agar tidak konflik)
// ==========================================
func makeEngineTestParam(nama string, nilai, min, max float64) models.AssessmentParamInput {
	return models.AssessmentParamInput{
		NamaParameter:   nama,
		NilaiHasil:      nilai,
		NilaiBatasBawah: min,
		NilaiBatasAtas:  max,
	}
}

// ==========================================
// UNIT TEST: Interpretasi TSHs
// ==========================================

// UT-TSH-01: TSH di bawah batas bawah → Rendah
func TestTSH_Rendah(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 0.1, 0.35, 4.94),
	})
	if result.StatusTSH != "Rendah" {
		t.Errorf("UT-TSH-01 GAGAL: expected 'Rendah', got '%s'", result.StatusTSH)
	} else {
		t.Logf("UT-TSH-01 LULUS: TSH=0.1 (min=0.35, max=4.94) → '%s'", result.StatusTSH)
	}
}

// UT-TSH-02: TSH dalam rentang → Normal
func TestTSH_Normal(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 2.5, 0.35, 4.94),
	})
	if result.StatusTSH != "Normal" {
		t.Errorf("UT-TSH-02 GAGAL: expected 'Normal', got '%s'", result.StatusTSH)
	} else {
		t.Logf("UT-TSH-02 LULUS: TSH=2.5 (min=0.35, max=4.94) → '%s'", result.StatusTSH)
	}
}

// UT-TSH-03: TSH di atas batas atas → Tinggi
func TestTSH_Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 6.0, 0.35, 4.94),
	})
	if result.StatusTSH != "Tinggi" {
		t.Errorf("UT-TSH-03 GAGAL: expected 'Tinggi', got '%s'", result.StatusTSH)
	} else {
		t.Logf("UT-TSH-03 LULUS: TSH=6.0 (min=0.35, max=4.94) → '%s'", result.StatusTSH)
	}
}

// ==========================================
// UNIT TEST: Interpretasi FT3
// ==========================================

// UT-FT3-01: FT3 di bawah batas bawah → Rendah
func TestFT3_Rendah(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT3", 1.0, 1.71, 3.71),
	})
	if result.StatusFT3 != "Rendah" {
		t.Errorf("UT-FT3-01 GAGAL: expected 'Rendah', got '%s'", result.StatusFT3)
	} else {
		t.Logf("UT-FT3-01 LULUS: FT3=1.0 (min=1.71, max=3.71) → '%s'", result.StatusFT3)
	}
}

// UT-FT3-02: FT3 dalam rentang → Normal
func TestFT3_Normal(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT3", 2.5, 1.71, 3.71),
	})
	if result.StatusFT3 != "Normal" {
		t.Errorf("UT-FT3-02 GAGAL: expected 'Normal', got '%s'", result.StatusFT3)
	} else {
		t.Logf("UT-FT3-02 LULUS: FT3=2.5 (min=1.71, max=3.71) → '%s'", result.StatusFT3)
	}
}

// UT-FT3-03: FT3 di atas batas atas → Tinggi
func TestFT3_Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT3", 5.0, 1.71, 3.71),
	})
	if result.StatusFT3 != "Tinggi" {
		t.Errorf("UT-FT3-03 GAGAL: expected 'Tinggi', got '%s'", result.StatusFT3)
	} else {
		t.Logf("UT-FT3-03 LULUS: FT3=5.0 (min=1.71, max=3.71) → '%s'", result.StatusFT3)
	}
}

// ==========================================
// UNIT TEST: Interpretasi FT4
// ==========================================

// UT-FT4-01: FT4 di bawah batas bawah → Rendah
func TestFT4_Rendah(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT4", 0.5, 0.70, 1.48),
	})
	if result.StatusFT4 != "Rendah" {
		t.Errorf("UT-FT4-01 GAGAL: expected 'Rendah', got '%s'", result.StatusFT4)
	} else {
		t.Logf("UT-FT4-01 LULUS: FT4=0.5 (min=0.70, max=1.48) → '%s'", result.StatusFT4)
	}
}

// UT-FT4-02: FT4 dalam rentang → Normal
func TestFT4_Normal(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT4", 1.0, 0.70, 1.48),
	})
	if result.StatusFT4 != "Normal" {
		t.Errorf("UT-FT4-02 GAGAL: expected 'Normal', got '%s'", result.StatusFT4)
	} else {
		t.Logf("UT-FT4-02 LULUS: FT4=1.0 (min=0.70, max=1.48) → '%s'", result.StatusFT4)
	}
}

// UT-FT4-03: FT4 di atas batas atas → Tinggi
func TestFT4_Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("FT4", 2.0, 0.70, 1.48),
	})
	if result.StatusFT4 != "Tinggi" {
		t.Errorf("UT-FT4-03 GAGAL: expected 'Tinggi', got '%s'", result.StatusFT4)
	} else {
		t.Logf("UT-FT4-03 LULUS: FT4=2.0 (min=0.70, max=1.48) → '%s'", result.StatusFT4)
	}
}

// ==========================================
// UNIT TEST: Interpretasi TRAb
// ==========================================

// UT-TRAb-01: TRAb <= cutoff → Negatif
func TestTRAb_Negatif(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TRAB", 1.5, 0.0, 2.0),
	})
	if result.StatusTRAb != "Negatif" {
		t.Errorf("UT-TRAb-01 GAGAL: expected 'Negatif', got '%s'", result.StatusTRAb)
	} else {
		t.Logf("UT-TRAb-01 LULUS: TRAb=1.5 (cutoff=2.0) → '%s'", result.StatusTRAb)
	}
}

// UT-TRAb-02: TRAb > cutoff → Positif
func TestTRAb_Positif(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TRAB", 3.5, 0.0, 2.0),
	})
	if result.StatusTRAb != "Positif" {
		t.Errorf("UT-TRAb-02 GAGAL: expected 'Positif', got '%s'", result.StatusTRAb)
	} else {
		t.Logf("UT-TRAb-02 LULUS: TRAb=3.5 (cutoff=2.0) → '%s'", result.StatusTRAb)
	}
}

// ==========================================
// UNIT TEST: Interpretasi Kondisi Graves Disease
// ==========================================

// UT-GD-01: TSH Normal + FT3 Normal + FT4 Normal → Normal
func TestGD_Normal(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 2.5, 0.35, 4.94),
		makeEngineTestParam("FT3", 2.5, 1.71, 3.71),
		makeEngineTestParam("FT4", 1.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Normal" {
		t.Errorf("UT-GD-01 GAGAL: expected 'Normal', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-01 LULUS: TSH=Normal, FT3=Normal, FT4=Normal → '%s'", result.Interpretasi)
	}
}

// UT-GD-02: TSH Rendah + FT3 Tinggi + FT4 Tinggi → Belum Normal
func TestGD_BelumNormal_SemuaTinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 0.1, 0.35, 4.94),
		makeEngineTestParam("FT3", 5.0, 1.71, 3.71),
		makeEngineTestParam("FT4", 2.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Belum Normal" {
		t.Errorf("UT-GD-02 GAGAL: expected 'Belum Normal', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-02 LULUS: TSH=Rendah, FT3=Tinggi, FT4=Tinggi → '%s'", result.Interpretasi)
	}
}

// UT-GD-03: TSH Rendah + FT3 Normal + FT4 Tinggi → Belum Normal
func TestGD_BelumNormal_FT4Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 0.1, 0.35, 4.94),
		makeEngineTestParam("FT3", 2.5, 1.71, 3.71),
		makeEngineTestParam("FT4", 2.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Belum Normal" {
		t.Errorf("UT-GD-03 GAGAL: expected 'Belum Normal', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-03 LULUS: TSH=Rendah, FT3=Normal, FT4=Tinggi → '%s'", result.Interpretasi)
	}
}

// UT-GD-03b: TSH Rendah + FT3 Normal + FT4 Normal → Belum Normal (Rule 9)
func TestGD_BelumNormal_Rule9(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 0.1, 0.35, 4.94),
		makeEngineTestParam("FT3", 2.5, 1.71, 3.71),
		makeEngineTestParam("FT4", 1.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Belum Normal" {
		t.Errorf("UT-GD-03b GAGAL: expected 'Belum Normal', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-03b LULUS: TSH=Rendah, FT3=Normal, FT4=Normal → '%s'", result.Interpretasi)
	}
}

// UT-GD-04: TSH Tinggi + FT3 Rendah + FT4 Tinggi → Tidak Terinterpretasi
func TestGD_TidakTerinterpretasi_TSHTinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 6.0, 0.35, 4.94),
		makeEngineTestParam("FT3", 1.0, 1.71, 3.71),
		makeEngineTestParam("FT4", 2.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Tidak Terinterpretasi" {
		t.Errorf("UT-GD-04 GAGAL: expected 'Tidak Terinterpretasi', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-04 LULUS: TSH=Tinggi, FT3=Rendah, FT4=Tinggi → '%s'", result.Interpretasi)
	}
}

// UT-GD-05: TSH Normal + FT3 Tinggi + FT4 Normal → Tidak Terinterpretasi
func TestGD_TidakTerinterpretasi_FT3Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 2.5, 0.35, 4.94),
		makeEngineTestParam("FT3", 5.0, 1.71, 3.71),
		makeEngineTestParam("FT4", 1.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Tidak Terinterpretasi" {
		t.Errorf("UT-GD-05 GAGAL: expected 'Tidak Terinterpretasi', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-05 LULUS: TSH=Normal, FT3=Tinggi, FT4=Normal → '%s'", result.Interpretasi)
	}
}

// UT-GD-06: TSH Normal + FT3 Normal + FT4 Tinggi → Tidak Terinterpretasi
func TestGD_TidakTerinterpretasi_FT4Tinggi(t *testing.T) {
	result := AnalyzeLabResults([]models.AssessmentParamInput{
		makeEngineTestParam("TSH", 2.5, 0.35, 4.94),
		makeEngineTestParam("FT3", 2.5, 1.71, 3.71),
		makeEngineTestParam("FT4", 2.0, 0.70, 1.48),
	})
	if result.Interpretasi != "Tidak Terinterpretasi" {
		t.Errorf("UT-GD-06 GAGAL: expected 'Tidak Terinterpretasi', got '%s'", result.Interpretasi)
	} else {
		t.Logf("UT-GD-06 LULUS: TSH=Normal, FT3=Normal, FT4=Tinggi → '%s'", result.Interpretasi)
	}
}

// ==========================================
// UNIT TEST: Interpretasi Data Wearable
// ==========================================

func statusHR(hr int) string {
	if hr == 0 { return "Tidak Ada Data" }
	if hr < 60 { return "Rendah" }
	if hr <= 100 { return "Normal" }
	return "Tinggi"
}

func statusTidur(menit int) string {
	if menit == 0 { return "Tidak Ada Data" }
	if menit < 420 { return "Kurang" }
	if menit <= 540 { return "Normal" }
	return "Berlebih"
}

func statusTD(sis, dia int) string {
	if sis == 0 || dia == 0 { return "Tidak Ada Data" }
	if sis < 120 && dia < 80 { return "Normal" }
	return "Tinggi"
}

// UT-HR-01: HR < 60 → Rendah
func TestWearable_HR_Rendah(t *testing.T) {
	s := statusHR(55)
	if s != "Rendah" {
		t.Errorf("UT-HR-01 GAGAL: expected 'Rendah', got '%s'", s)
	} else {
		t.Logf("UT-HR-01 LULUS: HR=55 → '%s'", s)
	}
}

// UT-HR-02: HR 60–100 → Normal
func TestWearable_HR_Normal(t *testing.T) {
	s := statusHR(80)
	if s != "Normal" {
		t.Errorf("UT-HR-02 GAGAL: expected 'Normal', got '%s'", s)
	} else {
		t.Logf("UT-HR-02 LULUS: HR=80 → '%s'", s)
	}
}

// UT-HR-03: HR > 100 → Tinggi
func TestWearable_HR_Tinggi(t *testing.T) {
	s := statusHR(110)
	if s != "Tinggi" {
		t.Errorf("UT-HR-03 GAGAL: expected 'Tinggi', got '%s'", s)
	} else {
		t.Logf("UT-HR-03 LULUS: HR=110 → '%s'", s)
	}
}

// UT-TIDUR-01: < 420 menit → Kurang
func TestWearable_Tidur_Kurang(t *testing.T) {
	s := statusTidur(360)
	if s != "Kurang" {
		t.Errorf("UT-TIDUR-01 GAGAL: expected 'Kurang', got '%s'", s)
	} else {
		t.Logf("UT-TIDUR-01 LULUS: Sleep=360 menit → '%s'", s)
	}
}

// UT-TIDUR-02: 420–540 menit → Normal
func TestWearable_Tidur_Normal(t *testing.T) {
	s := statusTidur(480)
	if s != "Normal" {
		t.Errorf("UT-TIDUR-02 GAGAL: expected 'Normal', got '%s'", s)
	} else {
		t.Logf("UT-TIDUR-02 LULUS: Sleep=480 menit → '%s'", s)
	}
}

// UT-TIDUR-03: > 540 menit → Berlebih
func TestWearable_Tidur_Berlebih(t *testing.T) {
	s := statusTidur(600)
	if s != "Berlebih" {
		t.Errorf("UT-TIDUR-03 GAGAL: expected 'Berlebih', got '%s'", s)
	} else {
		t.Logf("UT-TIDUR-03 LULUS: Sleep=600 menit → '%s'", s)
	}
}

// UT-TD-01: Sistolik < 120 dan Diastolik < 80 → Normal
func TestWearable_TD_Normal(t *testing.T) {
	s := statusTD(115, 75)
	if s != "Normal" {
		t.Errorf("UT-TD-01 GAGAL: expected 'Normal', got '%s'", s)
	} else {
		t.Logf("UT-TD-01 LULUS: Sistolik=115, Diastolik=75 → '%s'", s)
	}
}

// UT-TD-02: Sistolik >= 120 → Tinggi
func TestWearable_TD_Tinggi(t *testing.T) {
	s := statusTD(130, 85)
	if s != "Tinggi" {
		t.Errorf("UT-TD-02 GAGAL: expected 'Tinggi', got '%s'", s)
	} else {
		t.Logf("UT-TD-02 LULUS: Sistolik=130, Diastolik=85 → '%s'", s)
	}
}

// ==========================================
// UNIT TEST: Interpretasi Tren
// ==========================================

// UT-TREN-TSH-01: TSH Rendah, nilai naik → Mendekati Normal
func TestTren_TSH_MendekatiNormal(t *testing.T) {
	tren, _ := trenTSH(0.05, 0.20, "Rendah")
	if tren != "Mendekati Normal" {
		t.Errorf("UT-TREN-TSH-01 GAGAL: expected 'Mendekati Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-TSH-01 LULUS: TSH Rendah, 0.05→0.20 → '%s'", tren)
	}
}

// UT-TREN-TSH-02: TSH Rendah, nilai turun → Menjauhi Normal
func TestTren_TSH_MenjauhiNormal(t *testing.T) {
	tren, _ := trenTSH(0.20, 0.05, "Rendah")
	if tren != "Menjauhi Normal" {
		t.Errorf("UT-TREN-TSH-02 GAGAL: expected 'Menjauhi Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-TSH-02 LULUS: TSH Rendah, 0.20→0.05 → '%s'", tren)
	}
}

// UT-TREN-TSH-03: TSH Normal → Tetap Normal
func TestTren_TSH_TetapNormal(t *testing.T) {
	tren, _ := trenTSH(2.0, 2.5, "Normal")
	if tren != "Tetap Normal" {
		t.Errorf("UT-TREN-TSH-03 GAGAL: expected 'Tetap Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-TSH-03 LULUS: TSH Normal → '%s'", tren)
	}
}

// UT-TREN-FT4-01: FT4 Tinggi, nilai turun → Mendekati Normal
func TestTren_FT4_MendekatiNormal(t *testing.T) {
	tren, _ := trenFT4(2.5, 1.8, "Tinggi")
	if tren != "Mendekati Normal" {
		t.Errorf("UT-TREN-FT4-01 GAGAL: expected 'Mendekati Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-FT4-01 LULUS: FT4 Tinggi, 2.5→1.8 → '%s'", tren)
	}
}

// UT-TREN-FT4-02: FT4 Tinggi, nilai naik → Menjauhi Normal
func TestTren_FT4_MenjauhiNormal(t *testing.T) {
	tren, _ := trenFT4(1.8, 2.5, "Tinggi")
	if tren != "Menjauhi Normal" {
		t.Errorf("UT-TREN-FT4-02 GAGAL: expected 'Menjauhi Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-FT4-02 LULUS: FT4 Tinggi, 1.8→2.5 → '%s'", tren)
	}
}

// UT-TREN-TRAB-01: TRAb Positif, nilai turun → Mendekati Normal
func TestTren_TRAb_MendekatiNormal(t *testing.T) {
	tren, _ := trenTRAb(4.0, 2.5, "Positif")
	if tren != "Mendekati Normal" {
		t.Errorf("UT-TREN-TRAB-01 GAGAL: expected 'Mendekati Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-TRAB-01 LULUS: TRAb Positif, 4.0→2.5 → '%s'", tren)
	}
}

// UT-TREN-TRAB-02: TRAb Negatif → Tetap Normal
func TestTren_TRAb_TetapNormal(t *testing.T) {
	tren, _ := trenTRAb(1.5, 1.2, "Negatif")
	if tren != "Tetap Normal" {
		t.Errorf("UT-TREN-TRAB-02 GAGAL: expected 'Tetap Normal', got '%s'", tren)
	} else {
		t.Logf("UT-TREN-TRAB-02 LULUS: TRAb Negatif → '%s'", tren)
	}
}