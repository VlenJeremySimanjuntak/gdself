package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type KepatuhanObatUsecase interface {
	GetKepatuhanObat(obatID uint) (models.HasilKepatuhanObat, error)
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

func (u *kepatuhanObatUsecase) GetKepatuhanObat(obatID uint) (models.HasilKepatuhanObat, error) {
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

	statusLog, err := u.kepatuhanRepo.GetStatusLog(obatID)
	if err != nil {
		return models.HasilKepatuhanObat{}, err
	}

	var tglMulai time.Time
	if obat.TglMulai != nil {
		tglMulai = time.Time(*obat.TglMulai)
	}

	statTotal, err := u.kepatuhanRepo.GetStatTotal(obatID, tglMulai, obat.Frekuensi)
	if err != nil {
		return models.HasilKepatuhanObat{}, err
	}

	return evaluateKepatuhanObat(obat, statDiminum, statTotal, statusLog), nil
}

func evaluateKepatuhanObat(obat models.Obat, statDiminum int, statTotal int, statusLog []string) models.HasilKepatuhanObat {
    result := models.HasilKepatuhanObat{
        IDObat:      obat.IDObat,
        NamaObat:    obat.NamaObat,
        StatDiminum: statDiminum,
        StatTotal:   statTotal,
        StatusLog:   statusLog,
    }

    // ===== GERBANG AKTIVASI =====
    jumlahDataValid := 0
    hitungTerlewat := 0
    for _, status := range statusLog {
        if status != "" {
            jumlahDataValid++
        }
    }

    if jumlahDataValid < 3 {
        result.StatusKepatuhan = "Menunggu Data"
        result.PesanEdukasi = "Evaluasi kepatuhan akan dimulai setelah " +
            "3 jadwal minum obat pertama tercatat."
        return result
    }

    // ===== LAPIS 1: Deteksi Cepat =====
    for _, status := range statusLog {
        if status == "Terlewat" {
            hitungTerlewat++
        }
    }

    if hitungTerlewat >= 2 {
        result.StatusKepatuhan = "Belum Konsisten"
        result.PesanEdukasi = "Konsumsi obat belum berjalan secara konsisten. " +
            "Perhatikan kembali jadwal obat untuk menjaga keteraturan terapi."
        return result
    }

    // ===== LAPIS 2: Tinjauan Kumulatif =====
    if statTotal <= 0 {
        result.StatusKepatuhan = "Menunggu Data"
        result.PesanEdukasi = "Evaluasi kepatuhan akan aktif setelah " +
            "tiga jadwal konsumsi obat tercatat."
        return result
    }

    rasioKumulatif := (float64(statDiminum) / float64(statTotal)) * 100
    if rasioKumulatif < 80.0 {
        result.StatusKepatuhan = "Perlu Peninjauan"
        result.PesanEdukasi = "Kepatuhan konsumsi obat perlu ditingkatkan. " +
            "Pastikan obat diminum sesuai jadwal."
        return result
    }

    result.StatusKepatuhan = "Baik"
    result.PesanEdukasi = "Kepatuhan konsumsi obat Anda sudah baik. " +
        "Pertahankan konsistensi jadwal obat."
    return result
}
