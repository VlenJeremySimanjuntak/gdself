package usecases

import (
	"fmt"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAILabUsecase interface {
	CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error)
	CreateFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error)
	UpsertFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error) // ✅ PASTIKAN BARIS INI ADA
	GetHasilAILabByID(id uint) (models.HasilAILab, error)
	GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error)
}

type hasilAILabUsecase struct {
	repo repositories.HasilAILabRepository
}

func NewHasilAILabUsecase(repo repositories.HasilAILabRepository) HasilAILabUsecase {
	return &hasilAILabUsecase{repo: repo}
}

func (u *hasilAILabUsecase) CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error) {
	if lab.IDLaporanLab == 0 {
		return models.HasilAILab{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}
	return u.repo.Create(lab)
}

func (u *hasilAILabUsecase) CreateFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error) {
	if laporanLabID == 0 {
		return models.HasilAILab{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}

	hasil := AnalyzeLabResults(params)

	lab := models.HasilAILab{
		IDLaporanLab: laporanLabID,
		StatusTsh:    hasil.StatusTSH,
		ReminderTsh:  hasil.ReminderTSH,
		StatusFt3:    hasil.StatusFT3,
		ReminderFt3:  hasil.ReminderFT3,
		StatusFt4:    hasil.StatusFT4,
		ReminderFt4:  hasil.ReminderFT4,
		StatusTrab:   hasil.StatusTRAb,
		ReminderTrab: hasil.ReminderTRAb,
		Interpretasi: hasil.Interpretasi,
	}

	return u.repo.Create(lab)
}

// ✅ PASTIKAN FUNGSI INI ADA
func (u *hasilAILabUsecase) UpsertFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error) {
	if laporanLabID == 0 {
		return models.HasilAILab{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}

	hasil := AnalyzeLabResults(params)

	lab := models.HasilAILab{
		IDLaporanLab: laporanLabID,
		StatusTsh:    hasil.StatusTSH,
		ReminderTsh:  hasil.ReminderTSH,
		StatusFt3:    hasil.StatusFT3,
		ReminderFt3:  hasil.ReminderFT3,
		StatusFt4:    hasil.StatusFT4,
		ReminderFt4:  hasil.ReminderFT4,
		StatusTrab:   hasil.StatusTRAb,
		ReminderTrab: hasil.ReminderTRAb,
		Interpretasi: hasil.Interpretasi,
	}

	return u.repo.Upsert(lab)
}

func (u *hasilAILabUsecase) GetHasilAILabByID(id uint) (models.HasilAILab, error) {
	return u.repo.GetByID(id)
}

func (u *hasilAILabUsecase) GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error) {
	return u.repo.GetByLaporanLabID(laporanLabID)
}