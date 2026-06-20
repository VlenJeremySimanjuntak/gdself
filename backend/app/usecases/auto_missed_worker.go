package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"gorm.io/gorm"
)

// Mengambil singkatan hari sesuai database Flutter
func getHariPendek(w time.Weekday) string {
	hari := []string{"MIN", "SEN", "SEL", "RAB", "KAM", "JUM", "SAB"}
	return hari[w]
}

func StartMissedDoseChecker(db *gorm.DB) {
	fmt.Println("🚀 Background Worker: Auto-Missed Checker berjalan (Mode Testing 30 Detik)...")

	// 1. SET TIMEZONE KHUSUS INDONESIA (WIB)
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		fmt.Println("⚠️ Peringatan: Gagal load timezone Asia/Jakarta, menggunakan waktu server lokal.")
		loc = time.Local
	}

	go func() {
		for {
			time.Sleep(30 * time.Second)

			now := time.Now().In(loc)
			hariIni := getHariPendek(now.Weekday())

			var jadwalHariIni []models.JadwalObat
			db.Where("hari LIKE ?", "%"+hariIni+"%").Find(&jadwalHariIni)

			for _, jadwal := range jadwalHariIni {
				if jadwal.WaktuMinumObat == nil {
					continue
				}

				jamJadwal := time.Time(*jadwal.WaktuMinumObat)
				targetWaktu := time.Date(now.Year(), now.Month(), now.Day(), jamJadwal.Hour(), jamJadwal.Minute(), 0, 0, loc)
				
				// TESTING: Batas toleransi 3 Menit
				batasToleransi := targetWaktu.Add(3 * time.Minute)

				if now.After(batasToleransi) {
					var count int64
					todayWIB := now.Format("2006-01-02")       // Tanggal versi Jakarta
					todayUTC := now.UTC().Format("2006-01-02") // Tanggal versi Global Server

					// 🔥 ULTIMATE FIX: Gunakan Raw Query SQL murni
					// Ini membypass tipe data CustomDate Golang dan langsung bertanya ke MySQL
					query := `SELECT COUNT(*) FROM log_konsumsi_obat 
							  WHERE id_jadwal_obat = ? 
							  AND (DATE(tgl_konsumsi) = ? OR DATE(tgl_konsumsi) = ?)`
					
					errCount := db.Raw(query, jadwal.IDJadwalObat, todayWIB, todayUTC).Scan(&count).Error

					if errCount != nil {
						fmt.Printf("❌ [ERROR DB] Gagal mengecek log untuk Jadwal %d: %v\n", jadwal.IDJadwalObat, errCount)
						continue
					}

					// Jika count == 0, berarti BENAR-BENAR belum ada log hari ini
					if count == 0 {
						tglCustom := models.CustomDate(now)
						logBaru := models.LogKonsumsiObat{
							IDJadwalObat: jadwal.IDJadwalObat,
							TglKonsumsi:  &tglCustom,
							Status:       "Terlewat",
						}
						
						if err := db.Create(&logBaru).Error; err == nil {
							fmt.Printf("✅ [SUCCESS] Jadwal %d otomatis ditandai 'Terlewat' ke Database!\n", jadwal.IDJadwalObat)
						} else {
							fmt.Printf("❌ [ERROR INSERT] Gagal menyimpan ke DB: %v\n", err)
						}
					}
				}
			}
		}
	}()
}