package usecases

import (
    "fmt"
    "time"

    "monitoring-service/app/models"
    "monitoring-service/app/repositories"
)

type LogKonsumsiUsecase interface {
    CatatKonsumsi(jadwalID uint, tgl models.CustomDate, status string) (models.LogKonsumsiObat, error)
    GetByJadwalID(jadwalID uint) ([]models.LogKonsumsiObat, error)
    GetByJadwalIDAndDate(jadwalID uint, tgl models.CustomDate) (models.LogKonsumsiObat, error)
    HapusLog(id uint) error
    GetKepatuhanByObatID(obatID uint) (int64, []string, error)
}

type logKonsumsiUsecase struct {
    repo repositories.LogKonsumsiRepository
}

func NewLogKonsumsiUsecase(repo repositories.LogKonsumsiRepository) LogKonsumsiUsecase {
    return &logKonsumsiUsecase{repo: repo}
}

// CatatKonsumsi — buat atau update log untuk jadwal + tanggal tertentu
func (u *logKonsumsiUsecase) CatatKonsumsi(jadwalID uint, tgl models.CustomDate, status string) (models.LogKonsumsiObat, error) {
    if jadwalID == 0 {
        return models.LogKonsumsiObat{}, fmt.Errorf("id_jadwal_obat tidak boleh kosong")
    }

    validStatus := map[string]bool{
        "Diminum":  true, // user tap "Sudah Diminum"
        "Terlewat": true, // sistem auto-catat setelah batal 2x
    }

    if !validStatus[status] {
        return models.LogKonsumsiObat{}, fmt.Errorf("status tidak valid, gunakan: Diminum / Terlewat")
    }

    // Kalau tanggal kosong, pakai hari ini
    if time.Time(tgl).IsZero() {
        tgl = models.CustomDate(time.Now())
    }

    // Cek apakah sudah ada log untuk jadwal + tanggal ini
    existing, err := u.repo.GetByJadwalIDAndDate(jadwalID, tgl)
    if err == nil && existing.IDLog != 0 {
        
        // GUARD: Tolak update jika status saat ini sudah "Terlewat"
        if existing.Status == "Terlewat" {
            return existing, fmt.Errorf("Jadwal obat ini sudah terlewat")
        }

        // Update status jika belum Terlewat (misal: pending -> Diminum)
        existing.Status = status
        return u.repo.Update(existing.IDLog, existing)
    }

    // Buat log baru
    return u.repo.Create(models.LogKonsumsiObat{
        IDJadwalObat: jadwalID,
        TglKonsumsi:  &tgl,
        Status:       status,
    })
}

func (u *logKonsumsiUsecase) GetByJadwalID(jadwalID uint) ([]models.LogKonsumsiObat, error) {
    if jadwalID == 0 {
        return nil, fmt.Errorf("id_jadwal_obat tidak valid")
    }
    return u.repo.GetByJadwalID(jadwalID)
}

func (u *logKonsumsiUsecase) GetByJadwalIDAndDate(jadwalID uint, tgl models.CustomDate) (models.LogKonsumsiObat, error) {
    return u.repo.GetByJadwalIDAndDate(jadwalID, tgl)
}

func (u *logKonsumsiUsecase) HapusLog(id uint) error {
    if id == 0 {
        return fmt.Errorf("id tidak valid")
    }
    log, err := u.repo.GetByID(id)
    if err != nil || log.IDLog == 0 {
        return fmt.Errorf("log tidak ditemukan")
    }
    return u.repo.Delete(id)
}

func (u *logKonsumsiUsecase) GetKepatuhanByObatID(obatID uint) (int64, []string, error) {
    if obatID == 0 {
        return 0, nil, fmt.Errorf("id obat tidak valid")
    }
    return u.repo.GetKepatuhanByObatID(obatID)
}