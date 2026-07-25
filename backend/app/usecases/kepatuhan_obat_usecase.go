package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type KepatuhanObatUsecase interface {
	GetNotifikasiObat(obatID uint) (models.HasilNotifikasiObat, error)
	GetRekapObat(obatID uint) (models.HasilKepatuhanObat, error)
	GetNotifikasiObatUser(userID uint) ([]models.HasilNotifikasiObat, error)
}

type kepatuhanObatUsecase struct {
	kepatuhanRepo repositories.KepatuhanObatRepository
	obatRepo      repositories.ObatRepository
}

func NewKepatuhanObatUsecase(kepatuhanRepo repositories.KepatuhanObatRepository, obatRepo repositories.ObatRepository) KepatuhanObatUsecase {
	return &kepatuhanObatUsecase{
		kepatuhanRepo: kepatuhanRepo,
		obatRepo:      obatRepo,
	}
}

// ===== AI 1: Early Warning =====
func (u *kepatuhanObatUsecase) GetNotifikasiObat(obatID uint) (models.HasilNotifikasiObat, error) {
	if obatID == 0 {
		return models.HasilNotifikasiObat{}, fmt.Errorf("id_obat tidak valid")
	}

	obat, err := u.obatRepo.GetByID(obatID)
	if err != nil || obat.IDObat == 0 {
		return models.HasilNotifikasiObat{}, fmt.Errorf("obat tidak ditemukan")
	}

	detailLog, err := u.kepatuhanRepo.GetStatusLogDetailed(obatID)
	if err != nil {
		return models.HasilNotifikasiObat{}, err
	}

	return evaluateNotifikasiObat(obat, detailLog), nil
}

// ===== AI 2: Compliance Rate =====
func (u *kepatuhanObatUsecase) GetRekapObat(obatID uint) (models.HasilKepatuhanObat, error) {
    if obatID == 0 {
        return models.HasilKepatuhanObat{}, fmt.Errorf("id_obat tidak valid")
    }

    obat, err := u.obatRepo.GetByID(obatID)
    if err != nil || obat.IDObat == 0 {
        return models.HasilKepatuhanObat{}, fmt.Errorf("obat tidak ditemukan")
    }

    statDiminum, err := u.kepatuhanRepo.GetStatDiminum(obatID)
    if err != nil {
        return models.HasilKepatuhanObat{}, err
    }

    var tglMulai time.Time
    if obat.TglMulai != nil {
        tglMulai = time.Time(*obat.TglMulai)
    }

    now := time.Now()
    todayDate := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)

    var statTotal int

    if obat.TglSelesai != nil {
        endDate := time.Date(obat.TglSelesai.Year(), obat.TglSelesai.Month(), obat.TglSelesai.Day(), 0, 0, 0, 0, time.Local)

        if endDate.Before(todayDate) {
            statTotal, err = u.kepatuhanRepo.HitungStatTotalRekap(obatID, tglMulai, *obat.TglSelesai)
        } else {
            statTotal, err = u.kepatuhanRepo.GetStatTotal(obatID, tglMulai)
        }
    } else {
        statTotal, err = u.kepatuhanRepo.GetStatTotal(obatID, tglMulai)
    }

    if err != nil {
        return models.HasilKepatuhanObat{}, err
    }

    detailLog, err := u.kepatuhanRepo.GetStatusLogDetailed(obatID)
    if err == nil && len(detailLog) == 0 {
        statTotal = 0 
    }
    // =========================================================================

    return evaluateRekapObat(obat, statDiminum, statTotal), nil
}

func evaluateNotifikasiObat(obat models.Obat, detailLog []models.DetailLogKonsumsi) models.HasilNotifikasiObat {
	result := models.HasilNotifikasiObat{
		IDObat:          obat.IDObat,
		NamaObat:        obat.NamaObat,
		Detail:          detailLog,
		PerluNotifikasi: false,
	}

	if len(detailLog) < 3 {
		return result
	}

	jumlahTerlewat := 0
	for _, log := range detailLog {
		if log.Status == "Terlewat" {
			jumlahTerlewat++
		}
	}

	if jumlahTerlewat >= 2 {
		result.Status = "Belum Rutin"
		result.Ringkasan = fmt.Sprintf("%d dari 3 konsumsi terakhir terlewat", jumlahTerlewat)
		result.PerluNotifikasi = true
	}

	return result
}

func evaluateRekapObat(obat models.Obat, statDiminum int, statTotal int) models.HasilKepatuhanObat {
	result := models.HasilKepatuhanObat{
		IDObat:      obat.IDObat,
		NamaObat:    obat.NamaObat,
		StatDiminum: statDiminum,
		StatTotal:   statTotal,
	}

	if statTotal <= 0 {
		result.StatusKepatuhan = "Menunggu Data"
		result.PesanEdukasi = "Belum ada jadwal konsumsi obat yang tercatat."
		return result
	}

	result.Persentase = (float64(statDiminum) / float64(statTotal)) * 100

	if result.Persentase >= 80.0 {
		result.StatusKepatuhan = "Kepatuhan Baik"
		result.PesanEdukasi = "Tingkat kepatuhan minum obat berada pada kategori baik. Pertahankan keteraturan minum obat sesuai jadwal."
	} else {
		result.StatusKepatuhan = "Perlu Peninjauan"
		result.PesanEdukasi = "Tingkat kepatuhan minum obat masih perlu diperhatikan untuk meningkatkan keteraturan minum obat. "
	}

	return result
}

func (u *kepatuhanObatUsecase) GetNotifikasiObatUser(userID uint) ([]models.HasilNotifikasiObat, error) {
	obatList, err := u.obatRepo.GetByUserID(userID)
	if err != nil {
		return nil, err
	}

	var results []models.HasilNotifikasiObat
	for _, obat := range obatList {
		detailLog, err := u.kepatuhanRepo.GetStatusLogDetailed(obat.IDObat)
		if err != nil {
			continue
		}

		eval := evaluateNotifikasiObat(obat, detailLog)
		if eval.PerluNotifikasi {
			results = append(results, eval)
		}
	}

	return results, nil
}