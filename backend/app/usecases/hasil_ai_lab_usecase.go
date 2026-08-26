package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAILabUsecase interface {
	CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error)
	CreateFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error)
	UpsertFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error)
	GetHasilAILabByID(id uint) (models.HasilAILab, error)
	GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error)
	GetLatestValidByUserAndParam(userID uint, paramKey string) (models.HasilAILab, error)
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

	// ✅ PERBAIKAN: Konversi time.Now() ke struct models.CustomDate
	sekarang := models.CustomDate(time.Now())

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
		TglHasilAi:   &sekarang, // ✅ PERBAIKAN: Gunakan alamat pointer (&)
	}

	return u.repo.Create(lab)
}

func (u *hasilAILabUsecase) UpsertFromAssessment(laporanLabID uint, params []models.AssessmentParamInput) (models.HasilAILab, error) {
	if laporanLabID == 0 {
		return models.HasilAILab{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}

	hasil := AnalyzeLabResults(params)

	// ✅ PERBAIKAN: Konversi time.Now() ke struct models.CustomDate
	sekarang := models.CustomDate(time.Now())

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
		TglHasilAi:   &sekarang, // ✅ PERBAIKAN: Gunakan alamat pointer (&)
	}

	return u.repo.Upsert(lab)
}

func (u *hasilAILabUsecase) GetHasilAILabByID(id uint) (models.HasilAILab, error) {
	return u.repo.GetByID(id)
}

func (u *hasilAILabUsecase) GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error) {
	return u.repo.GetByLaporanLabID(laporanLabID)
}

func (u *hasilAILabUsecase) GetLatestValidByUserAndParam(userID uint, paramKey string) (models.HasilAILab, error) {
	columnMap := map[string]string{
		"TSH":  "status_tsh",
		"FT3":  "status_ft3",
		"FT4":  "status_ft4",
		"TRAB": "status_trab",
	}
	column, ok := columnMap[paramKey]
	if !ok {
		return models.HasilAILab{}, fmt.Errorf("parameter tidak dikenal: %s", paramKey)
	}
	return u.repo.GetLatestValidByUserAndParam(userID, column)
}