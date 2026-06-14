package usecases

import (
	"fmt"
	"strings"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type LabUsecase interface {
	SaveLabResult(input models.CreateHasilLabRequest) (models.HasilLab, error)
	GetAllLabResults() ([]models.HasilLab, error)
	GetLabResultsByUserID(userID uint) ([]models.HasilLab, error)
	Assess(input models.AssessmentInput) (models.AssessmentResult, error)
}

type labUsecase struct {
	repo           repositories.LabRepository
	repoParameter  repositories.ParameterRepository
	usecaseHasilAI HasilAIUsecase
}

func NewLabUsecase(r repositories.LabRepository, repoParam repositories.ParameterRepository, usecase ...HasilAIUsecase) LabUsecase {
	var usecaseAI HasilAIUsecase
	if len(usecase) > 0 {
		usecaseAI = usecase[0]
	}
	return &labUsecase{repo: r, repoParameter: repoParam, usecaseHasilAI: usecaseAI}
}

func (u *labUsecase) SaveLabResult(input models.CreateHasilLabRequest) (models.HasilLab, error) {
	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		idLaporan = input.IDReport
	}
	if idLaporan == 0 || input.IDRiwayat == 0 {
		return models.HasilLab{}, fmt.Errorf("id_laporan_lab dan id_riwayat wajib diisi")
	}
	if len(input.Parameters) == 0 {
		return models.HasilLab{}, fmt.Errorf("minimal 1 parameter harus diisi")
	}
	if u.repoParameter == nil {
		return models.HasilLab{}, fmt.Errorf("parameter repository belum dikonfigurasi")
	}

	paramReq := input.Parameters[0]
	paramName := strings.TrimSpace(paramReq.NamaParameter)
	if paramName == "" {
		return models.HasilLab{}, fmt.Errorf("nama_parameter tidak boleh kosong")
	}

	masterParam, err := u.repoParameter.GetByNamaParameter(paramName)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			masterParam, err = u.repoParameter.Create(models.Parameter{
				NamaParameter: strings.ToUpper(paramName),
				Satuan:        paramReq.Satuan,
				Kategori:      paramReq.Kategori,
			})
			if err != nil {
				return models.HasilLab{}, err
			}
		} else {
			return models.HasilLab{}, err
		}
	}

	hasilLab := models.HasilLab{
		IDLaporanLab: idLaporan,
		IDRiwayat:    input.IDRiwayat,
		IDParameter:  masterParam.IDParameter,
		NilaiHasil:   paramReq.Nilai,
		RujukanMin:   input.RujukanMin,
		RujukanMax:   input.RujukanMax,
	}

	// Simpan ke database
	return u.repo.Create(hasilLab)
}

func (u *labUsecase) GetAllLabResults() ([]models.HasilLab, error) {
	return u.repo.GetAll()
}

func (u *labUsecase) GetLabResultsByUserID(userID uint) ([]models.HasilLab, error) {
	return u.repo.GetByUserID(userID)
}
