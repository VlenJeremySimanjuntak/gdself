package repositories

import (
	"fmt"
	"strings"
	"time"

	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type KepatuhanObatRepository interface {
	GetStatDiminum(obatID uint) (int, error)
	GetStatTotal(obatID uint, tglMulai time.Time) (int, error)
	HitungStatTotalBerjalan(obatID uint, tglMulai time.Time) (int, error)
	HitungStatTotalRekap(obatID uint, tglMulai time.Time, tglSelesai time.Time) (int, error)
	GetStatusLogDetailed(obatID uint) ([]models.DetailLogKonsumsi, error) // Berubah
}

type kepatuhanObatRepository struct {
	db *gorm.DB
}

func NewKepatuhanObatRepository(db *gorm.DB) KepatuhanObatRepository {
	return &kepatuhanObatRepository{db: db}
}

func (r *kepatuhanObatRepository) GetStatDiminum(obatID uint) (int, error) {
	var statDiminum int64
	err := r.db.Table("log_konsumsi_obat").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ? AND log_konsumsi_obat.status = ?", obatID, "Diminum").
		Count(&statDiminum).Error
	if err != nil {
		return 0, err
	}

	return int(statDiminum), nil
}

func (r *kepatuhanObatRepository) HitungStatTotalBerjalan(obatID uint, tglMulai time.Time) (int, error) {
	if tglMulai.IsZero() {
		return 0, nil
	}
	today := time.Now()
	todayDate := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, time.Local)
	return r.hitungTotalDenganRentang(obatID, tglMulai, todayDate)
}

func (r *kepatuhanObatRepository) GetStatTotal(obatID uint, tglMulai time.Time) (int, error) {
	return r.HitungStatTotalBerjalan(obatID, tglMulai)
}

func (r *kepatuhanObatRepository) HitungStatTotalRekap(obatID uint, tglMulai time.Time, tglSelesai time.Time) (int, error) {
	if tglMulai.IsZero() || tglSelesai.IsZero() {
		return 0, nil
	}
	return r.hitungTotalDenganRentang(obatID, tglMulai, tglSelesai)
}

func (r *kepatuhanObatRepository) hitungTotalDenganRentang(obatID uint, tglMulai time.Time, tglAkhir time.Time) (int, error) {
    var jadwalList []models.JadwalObat
    if err := r.db.Where("id_obat = ?", obatID).Find(&jadwalList).Error; err != nil {
        return 0, err
    }
    if len(jadwalList) == 0 {
        return 0, nil
    }

    startDate := time.Date(tglMulai.Year(), tglMulai.Month(), tglMulai.Day(), 0, 0, 0, 0, time.Local)
    endDate := time.Date(tglAkhir.Year(), tglAkhir.Month(), tglAkhir.Day(), 0, 0, 0, 0, time.Local)
    if endDate.Before(startDate) {
        return 0, nil
    }

    now := time.Now()
    todayDate := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)

    total := 0
    for d := startDate; !d.After(endDate); d = d.AddDate(0, 0, 1) {
        isToday := d.Equal(todayDate)
        isPastDay := d.Before(todayDate)

        for _, jadwal := range jadwalList {
            // Cek apakah hari pada tanggal 'd' cocok dengan jadwal
            if strings.Contains(strings.ToUpper(jadwal.Hari), getHariPendek(d.Weekday())) {
                if isPastDay {
                    // 1. Jika hari di masa lalu, hitung semuanya
                    total++
                } else if isToday {
                    // 2. Jika hari ini, HANYA hitung jika jam jadwal sudah lewat dari jam sekarang
                    if isWaktuSudahLewat(jadwal.WaktuMinumObat, now) {
                        total++
                    }
                }
                // (Jika hari di masa depan, abaikan/tidak dihitung)
            }
        }
    }

    return total, nil
}

// Fungsi helper untuk membandingkan jam jadwal dengan jam saat ini
func isWaktuSudahLewat(waktuObat *models.CustomTime, now time.Time) bool {
    if waktuObat == nil {
        return false
    }
    t := time.Time(*waktuObat)
    
    // Bandingkan jam dan menit
    if now.Hour() > t.Hour() {
        return true
    }
    if now.Hour() == t.Hour() && now.Minute() >= t.Minute() {
        return true
    }
    return false
}

func hitungHariCocok(start, end time.Time, hariField string) int {
	hariField = strings.ToUpper(hariField)
	if hariField == "" {
		return 0
	}

	count := 0
	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		if strings.Contains(hariField, getHariPendek(d.Weekday())) {
			count++
		}
	}
	return count
}

func getHariPendek(w time.Weekday) string {
	hari := []string{"MIN", "SEN", "SEL", "RAB", "KAM", "JUM", "SAB"}
	return hari[w]
}

// Fungsi BARU pengambil detail log (tanggal, waktu, status)
func (r *kepatuhanObatRepository) GetStatusLogDetailed(obatID uint) ([]models.DetailLogKonsumsi, error) {
	type statusRow struct {
		Status     string    `gorm:"column:status"`
		Tgl        time.Time `gorm:"column:tgl_konsumsi"`
		WaktuMinum string    `gorm:"column:waktu_minum_obat"`
	}

	var rows []statusRow
	err := r.db.Table("log_konsumsi_obat").
		Select("log_konsumsi_obat.status, log_konsumsi_obat.tgl_konsumsi, jadwal_obat.waktu_minum_obat").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ?", obatID).
		Order("log_konsumsi_obat.tgl_konsumsi DESC, log_konsumsi_obat.id_log DESC").
		Limit(3).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	var detailLog []models.DetailLogKonsumsi
	
	// Dilakukan looping terbalik (dari belakang ke depan) agar urutan di frontend kronologis (paling lama ke paling baru)
	for i := len(rows) - 1; i >= 0; i-- {
		row := rows[i]
		
		jam := row.WaktuMinum
		if len(jam) >= 5 {
			jam = jam[:5] + " WIB" // Contoh: 08:00 WIB
		} else if len(jam) > 0 {
			jam = jam + " WIB"
		} else {
			jam = "-"
		}

		detailLog = append(detailLog, models.DetailLogKonsumsi{
			Tanggal: formatTanggalIndonesia(row.Tgl),
			Jam:     jam,
			Status:  row.Status,
		})
	}

	return detailLog, nil
}

func formatTanggalIndonesia(t time.Time) string {
	if t.IsZero() {
		return "-"
	}
	bulan := []string{"", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"}
	if int(t.Month()) < 1 || int(t.Month()) > 12 {
		return "-"
	}
	return fmt.Sprintf("%d %s", t.Day(), bulan[t.Month()])
}