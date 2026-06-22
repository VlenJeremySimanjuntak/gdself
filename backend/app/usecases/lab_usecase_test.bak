package usecases

import (
	"testing"

	"monitoring-service/app/models"
)

// ==========================================
// 1. MOCK REPOSITORIES & USECASES
// ==========================================

type mockLabRepository struct{}

func (m *mockLabRepository) Create(input models.HasilLab) (models.HasilLab, error) { return input, nil }
func (m *mockLabRepository) GetAll() ([]models.HasilLab, error)                    { return []models.HasilLab{}, nil }
func (m *mockLabRepository) GetByUserID(userID uint) ([]models.HasilLab, error)    { return []models.HasilLab{}, nil }

type mockParameterRepository struct{}

func (m *mockParameterRepository) Create(input models.Parameter) (models.Parameter, error) {
	return input, nil
}
func (m *mockParameterRepository) GetByNamaParameter(nama string) (models.Parameter, error) {
	return models.Parameter{IDParameter: 1, NamaParameter: nama}, nil
}
func (m *mockParameterRepository) GetByID(id uint) (models.Parameter, error) {
	return models.Parameter{}, nil
}
func (m *mockParameterRepository) GetAll() ([]models.Parameter, error) {
	return []models.Parameter{}, nil
}
func (m *mockParameterRepository) Update(id uint, input models.Parameter) (models.Parameter, error) {
	return input, nil
}
func (m *mockParameterRepository) Delete(id uint) error { return nil }

type mockHasilAILabUsecase struct{}

func (m *mockHasilAILabUsecase) CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error) {
	return lab, nil
}
func (m *mockHasilAILabUsecase) GetHasilAILabByID(id uint) (models.HasilAILab, error) {
	return models.HasilAILab{}, nil
}
func (m *mockHasilAILabUsecase) GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error) {
	return models.HasilAILab{}, nil
}

type mockHasilAITrenUsecase struct{}

func (m *mockHasilAITrenUsecase) CreateHasilAITren(tren models.HasilAITren) (models.HasilAITren, error) {
	return tren, nil
}
func (m *mockHasilAITrenUsecase) GetHasilAITrenByID(id uint) (models.HasilAITren, error) {
	return models.HasilAITren{}, nil
}
func (m *mockHasilAITrenUsecase) GetHasilAITrenByLaporanLabID(laporanLabID uint) (models.HasilAITren, error) {
	return models.HasilAITren{}, nil
}

// ==========================================
// 2. HELPER FUNCTIONS UNTUK TESTING
// ==========================================

// createParameters membuat dummy data parameter dengan mengisi field Nilai
func createParameters(ft3, ft4, tsh float64) []models.Parameter {
	return []models.Parameter{
		{IDParameter: 1, NamaParameter: "FT3", Nilai: ft3},
		{IDParameter: 2, NamaParameter: "FT4", Nilai: ft4},
		{IDParameter: 3, NamaParameter: "TSH", Nilai: tsh},
	}
}

// ==========================================
// 3. UNIT TESTS: RULE-BASED LOGIC (lab_rules.go)
// ==========================================

func TestAnalyzeLabResults_Normal(t *testing.T) {
	// Kasus Normal: TSH 1.5, FT3 3.0, FT4 10.0 (Semua dalam rentang constants)
	params := createParameters(3.0, 10.0, 1.5)
	
	res := AnalyzeLabResults(params)

	if res.StatusTSH != "Normal" {
		t.Errorf("Diharapkan StatusTSH Normal, didapat %s", res.StatusTSH)
	}
	if res.Interpretasi != "Kondisi tiroid stabil (Normal)." {
		t.Errorf("Diharapkan Normal, didapat: %s", res.Interpretasi)
	}
}

func TestAnalyzeLabResults_OvertGraves(t *testing.T) {
	// Kasus Overt Graves: TSH Rendah (<0.4), FT3 Tinggi (>4.2), FT4 Tinggi (>15.0)
	params := createParameters(5.0, 16.0, 0.1)

	res := AnalyzeLabResults(params)

	if res.StatusTSH != "Rendah" {
		t.Errorf("Diharapkan StatusTSH Rendah, didapat %s", res.StatusTSH)
	}
	expected := "Indikasi Overt Graves Disease (Hipertiroid nyata). Harap segera ke dokter."
	if res.Interpretasi != expected {
		t.Errorf("Diharapkan Overt Graves, didapat: %s", res.Interpretasi)
	}
}

func TestAnalyzeLabResults_T3Dominant(t *testing.T) {
	// Kasus T3-Toxicosis: TSH Rendah, FT3 Tinggi, FT4 Normal
	params := createParameters(5.0, 10.0, 0.1)

	res := AnalyzeLabResults(params)

	expected := "Indikasi Graves Disease dominan T3 (T3-toxicosis)."
	if res.Interpretasi != expected {
		t.Errorf("Diharapkan T3 Dominan, didapat: %s", res.Interpretasi)
	}
}

func TestAnalyzeLabResults_T4Dominant(t *testing.T) {
	// Kasus T4 Dominan: TSH Rendah, FT3 Normal, FT4 Tinggi
	params := createParameters(3.0, 16.0, 0.1)

	res := AnalyzeLabResults(params)

	expected := "Indikasi Graves Disease dominan T4."
	if res.Interpretasi != expected {
		t.Errorf("Diharapkan T4 Dominan, didapat: %s", res.Interpretasi)
	}
}

func TestAnalyzeLabResults_Unknown(t *testing.T) {
	// Kasus Ambigu: TSH Normal, tapi FT3 dan FT4 Tinggi (Pola tidak biasa)
	params := createParameters(6.0, 20.0, 2.0)

	res := AnalyzeLabResults(params)

	expected := "Kondisi tiroid tidak menentu atau di luar pola standar Graves. Perlu evaluasi medis lebih lanjut."
	if res.Interpretasi != expected {
		t.Errorf("Diharapkan Evaluasi Medis, didapat: %s", res.Interpretasi)
	}
}

// ==========================================
// 4. UNIT TESTS: USECASE ASSESS (lab_usecase.go)
// ==========================================

func TestLabUsecase_Assess(t *testing.T) {
	// Setup Mocks & Usecase
	repo := &mockLabRepository{}
	paramRepo := &mockParameterRepository{}
	aiLabUsecase := &mockHasilAILabUsecase{}
	aiTrenUsecase := &mockHasilAITrenUsecase{}

	usecase := NewLabUsecase(repo, paramRepo, aiLabUsecase, aiTrenUsecase)

	// Persiapkan Input Assessment (Simulasi Hasil Lab TSH normal)
	input := models.AssessmentInput{
		Lab: models.HasilLab{
			IDLaporanLab: 1,
			Parameters:   createParameters(3.5, 12.0, 2.0),
		},
	}

	// Eksekusi Assess
	result, err := usecase.Assess(input)

	if err != nil {
		t.Fatalf("Assess mengembalikan error yang tidak diharapkan: %v", err)
	}

	// Verifikasi apakah Assessment memanggil AnalyzeLabResults dengan benar
	if result.Interpretation != "Kondisi tiroid stabil (Normal)." {
		t.Errorf("Interpretasi akhir salah, didapat: %s", result.Interpretation)
	}
}