package usecases

import (
	"monitoring-service/app/models"
	"testing"
)

// Mock Repository untuk testing
type mockLabRepository struct{}

func (m *mockLabRepository) Create(input models.HasilLab) (models.HasilLab, error) {
	return input, nil
}

func (m *mockLabRepository) GetAll() ([]models.HasilLab, error) {
	return []models.HasilLab{}, nil
}

func (m *mockLabRepository) GetByUserID(userID uint) ([]models.HasilLab, error) {
	return []models.HasilLab{}, nil
}

// Mock Parameter Repository untuk testing
type mockParameterRepository struct{}

func (m *mockParameterRepository) Create(input models.Parameter) (models.Parameter, error) {
	return input, nil
}

func (m *mockParameterRepository) GetByNamaParameter(nama string) (models.Parameter, error) {
	return models.Parameter{}, nil
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

func (m *mockParameterRepository) Delete(id uint) error {
	return nil
}

// Mock HasilAI Usecase untuk testing
type mockHasilAIUsecase struct{}

func (m *mockHasilAIUsecase) GetHasilAIByID(id uint) (models.HasilAI, error) {
	return models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) GetHasilAIByRiwayatID(riwayatID uint) ([]models.HasilAI, error) {
	return []models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) GetHasilAIByWearableID(wearableID uint) ([]models.HasilAI, error) {
	return []models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) GetHasilAIByHasilLabID(hasilLabID uint) ([]models.HasilAI, error) {
	return []models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) GetAllHasilAI() ([]models.HasilAI, error) {
	return []models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) UpdateIsRead(id uint) (models.HasilAI, error) {
	return models.HasilAI{}, nil
}

func (m *mockHasilAIUsecase) CreateHasilAI(riwayatID uint, wearableID *uint, hasilLabID *uint, score float64) (models.HasilAI, error) {
	return models.HasilAI{IDHasilAI: 1}, nil
}

func (m *mockHasilAIUsecase) ProcessAIAssessment(req AssessRequest) (*models.HasilAI, error) {
	// Return a basic placeholder — tests don't assert on this
	res := &models.HasilAI{IDHasilAI: 1}
	return res, nil
}

// Helper function to create Parameters array
func createParameters(ft3, ft4, tsh float64) []models.Parameter {
	return []models.Parameter{
		{
			IDParameter:   1,
			NamaParameter: "FT3",
			Satuan:        "pmol/L",
			Kategori:      "Thyroid",
			Nilai:         ft3,
		},
		{
			IDParameter:   2,
			NamaParameter: "FT4",
			Satuan:        "pmol/L",
			Kategori:      "Thyroid",
			Nilai:         ft4,
		},
		{
			IDParameter:   3,
			NamaParameter: "TSH",
			Satuan:        "mIU/L",
			Kategori:      "Thyroid",
			Nilai:         tsh,
		},
	}
}

// Test Case 1: Lab Score = 1 (Normal)
func TestComputeLabScore_Normal(t *testing.T) {
	score, code := computeLabScore(3.5, 10.0, 1.5)
	if score != 1 || code != "1" {
		t.Errorf("Expected score=1, code='1', got score=%d, code='%s'", score, code)
	}
}

// Test Case 2: Lab Score = 2a (Graves Overt)
func TestComputeLabScore_GravesOvert(t *testing.T) {
	score, code := computeLabScore(4.5, 16.0, 0.3)
	if score != 2 || code != "2a" {
		t.Errorf("Expected score=2, code='2a', got score=%d, code='%s'", score, code)
	}
}

// Test Case 3: Lab Score = 2b (Graves T3-dominant)
func TestComputeLabScore_GravesT3Dom(t *testing.T) {
	score, code := computeLabScore(4.5, 10.0, 0.3)
	if score != 2 || code != "2b" {
		t.Errorf("Expected score=2, code='2b', got score=%d, code='%s'", score, code)
	}
}

// Test Case 4: Lab Score = 2c (Graves T4-dominant)
func TestComputeLabScore_GravesT4Dom(t *testing.T) {
	score, code := computeLabScore(3.5, 16.0, 0.3)
	if score != 2 || code != "2c" {
		t.Errorf("Expected score=2, code='2c', got score=%d, code='%s'", score, code)
	}
}

// Test Case 5: Lab Score = 3 (Unknown/Ambiguous)
func TestComputeLabScore_Unknown(t *testing.T) {
	score, code := computeLabScore(5.0, 3.0, 0.2)
	if score != 3 || code != "3" {
		t.Errorf("Expected score=3, code='3', got score=%d, code='%s'", score, code)
	}
}

// Test Case 6: Wearable Score = 1 (All Normal)
func TestComputeWearableScore_AllNormal(t *testing.T) {
	w := models.WearableData{
		HR:                75,
		Stress:            40,
		SleepMinutes:      480,
		BaselineHRMin:     60,
		BaselineHRMax:     80,
		BaselineStressMin: 20,
		BaselineStressMax: 50,
		BaselineSleepMin:  420,
		BaselineSleepMax:  540,
	}
	score := computeWearableScore(w)
	if score != 1 {
		t.Errorf("Expected score=1, got score=%d", score)
	}
}

// Test Case 7: Wearable Score = 2 (1 Metric Abnormal)
func TestComputeWearableScore_OneAbnormal(t *testing.T) {
	w := models.WearableData{
		HR:                90, // Out of range [60, 80]
		Stress:            40,
		SleepMinutes:      480,
		BaselineHRMin:     60,
		BaselineHRMax:     80,
		BaselineStressMin: 20,
		BaselineStressMax: 50,
		BaselineSleepMin:  420,
		BaselineSleepMax:  540,
	}
	score := computeWearableScore(w)
	if score != 2 {
		t.Errorf("Expected score=2, got score=%d", score)
	}
}

// Test Case 8: Wearable Score = 3 (2+ Metrics Abnormal)
func TestComputeWearableScore_MultipleAbnormal(t *testing.T) {
	w := models.WearableData{
		HR:                90, // Out of range
		Stress:            60, // Out of range
		SleepMinutes:      480,
		BaselineHRMin:     60,
		BaselineHRMax:     80,
		BaselineStressMin: 20,
		BaselineStressMax: 50,
		BaselineSleepMin:  420,
		BaselineSleepMax:  540,
	}
	score := computeWearableScore(w)
	if score != 3 {
		t.Errorf("Expected score=3, got score=%d", score)
	}
}

// Test Case 9: Trend Factor Y = 1.1 (Worsening)
func TestComputeTrendFactorY_Worsening(t *testing.T) {
	y := computeTrendFactorY(2, 1)
	if y != 1.1 {
		t.Errorf("Expected y=1.1, got y=%f", y)
	}
}

// Test Case 10: Trend Factor Y = 0.9 (Improving)
func TestComputeTrendFactorY_Improving(t *testing.T) {
	y := computeTrendFactorY(1, 2)
	if y != 0.9 {
		t.Errorf("Expected y=0.9, got y=%f", y)
	}
}

// Test Case 11: Trend Factor Y = 1.0 (Stable)
func TestComputeTrendFactorY_Stable(t *testing.T) {
	y := computeTrendFactorY(1, 1)
	if y != 1.0 {
		t.Errorf("Expected y=1.0, got y=%f", y)
	}
}

// Test Case 12: Full Assessment - Lab Day with Worsening Trend
func TestAssess_LabDayWorsening(t *testing.T) {
	repo := &mockLabRepository{}
	paramRepo := &mockParameterRepository{}
	usecase := NewLabUsecase(repo, paramRepo, &mockHasilAIUsecase{})

	input := models.AssessmentInput{
		Lab: models.HasilLab{
			IDHasilLab:   1,
			IDLaporanLab: 1,
			IDRiwayat:    1,
			NilaiHasil:   0.3,
			RujukanMin:   0.4,
			RujukanMax:   4.0,
			Parameters:   createParameters(4.5, 16.0, 0.3),
		},
		PrevLab: &models.HasilLab{
			IDHasilLab:   2,
			IDLaporanLab: 1,
			IDRiwayat:    1,
			NilaiHasil:   1.8,
			RujukanMin:   0.4,
			RujukanMax:   4.0,
			Parameters:   createParameters(3.2, 9.0, 1.8),
		},
		Wearable: models.WearableData{
			HR:                85,
			Stress:            55,
			SleepMinutes:      360,
			BaselineHRMin:     60,
			BaselineHRMax:     80,
			BaselineStressMin: 20,
			BaselineStressMax: 50,
			BaselineSleepMin:  420,
			BaselineSleepMax:  540,
		},
		IsLabDay: true,
	}

	result, err := usecase.Assess(input)
	if err != nil {
		t.Fatalf("Assess failed: %v", err)
	}

	if result.LabScore != 2 {
		t.Errorf("Expected LabScore=2, got %d", result.LabScore)
	}
	if result.LabCode != "2a" {
		t.Errorf("Expected LabCode='2a', got '%s'", result.LabCode)
	}
	if result.WearableScore != 3 {
		t.Errorf("Expected WearableScore=3, got %d", result.WearableScore)
	}
	if result.TrendFactorY != 1.1 {
		t.Errorf("Expected TrendFactorY=1.1, got %f", result.TrendFactorY)
	}
	// (2 × 1.1) × 0.7 + 3 × 0.3 = 1.54 + 0.9 = 2.44 ≈ 2.4
	if result.FinalScore < 2.3 || result.FinalScore > 2.5 {
		t.Errorf("Expected FinalScore around 2.4, got %f", result.FinalScore)
	}
	if result.Interpretation != "Graves disease / wearable jelek" {
		t.Errorf("Unexpected interpretation: %s", result.Interpretation)
	}
}

// Test Case 13: Full Assessment - Non-Lab Day
func TestAssess_NonLabDay(t *testing.T) {
	repo := &mockLabRepository{}
	paramRepo := &mockParameterRepository{}
	usecase := NewLabUsecase(repo, paramRepo, &mockHasilAIUsecase{})

	input := models.AssessmentInput{
		Lab: models.HasilLab{
			IDHasilLab:   1,
			IDLaporanLab: 1,
			IDRiwayat:    1,
			NilaiHasil:   1.5,
			RujukanMin:   0.4,
			RujukanMax:   4.0,
			Parameters:   createParameters(3.5, 10.0, 1.5),
		},
		Wearable: models.WearableData{
			HR:                72,
			Stress:            35,
			SleepMinutes:      480,
			BaselineHRMin:     60,
			BaselineHRMax:     80,
			BaselineStressMin: 20,
			BaselineStressMax: 50,
			BaselineSleepMin:  420,
			BaselineSleepMax:  540,
		},
		IsLabDay: false,
	}

	result, err := usecase.Assess(input)
	if err != nil {
		t.Fatalf("Assess failed: %v", err)
	}

	if result.LabScore != 1 {
		t.Errorf("Expected LabScore=1, got %d", result.LabScore)
	}
	if result.WearableScore != 1 {
		t.Errorf("Expected WearableScore=1, got %d", result.WearableScore)
	}
	if result.TrendFactorY != 1.0 {
		t.Errorf("Expected TrendFactorY=1.0, got %f", result.TrendFactorY)
	}
	// 1 × 0.7 + 1 × 0.3 = 1.0
	if result.FinalScore != 1.0 {
		t.Errorf("Expected FinalScore=1.0, got %f", result.FinalScore)
	}
	if result.Interpretation != "Normal / wearable normal" {
		t.Errorf("Unexpected interpretation: %s", result.Interpretation)
	}
}

// Test Case 14: Full Assessment - Unknown Condition
func TestAssess_UnknownCondition(t *testing.T) {
	repo := &mockLabRepository{}
	paramRepo := &mockParameterRepository{}
	usecase := NewLabUsecase(repo, paramRepo, &mockHasilAIUsecase{})

	input := models.AssessmentInput{
		Lab: models.HasilLab{
			IDHasilLab:   1,
			IDLaporanLab: 1,
			IDRiwayat:    1,
			NilaiHasil:   0.2,
			RujukanMin:   0.4,
			RujukanMax:   4.0,
			Parameters:   createParameters(5.0, 3.0, 0.2),
		},
		Wearable: models.WearableData{
			HR:                75,
			Stress:            40,
			SleepMinutes:      480,
			BaselineHRMin:     60,
			BaselineHRMax:     80,
			BaselineStressMin: 20,
			BaselineStressMax: 50,
			BaselineSleepMin:  420,
			BaselineSleepMax:  540,
		},
		IsLabDay: false,
	}

	result, err := usecase.Assess(input)
	if err != nil {
		t.Fatalf("Assess failed: %v", err)
	}

	if result.LabScore != 3 {
		t.Errorf("Expected LabScore=3, got %d", result.LabScore)
	}
	if result.LabCode != "3" {
		t.Errorf("Expected LabCode='3', got '%s'", result.LabCode)
	}
	if result.Interpretation != "Kondisi tidak diketahui / wearable normal" {
		t.Errorf("Unexpected interpretation: %s", result.Interpretation)
	}
}
