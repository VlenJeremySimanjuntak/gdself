package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"gorm.io/gorm"
)

// ✅ PERBAIKAN: Format hari disamakan dengan database Flutter (MIN, SEN, SEL, dst)
func getHariPendek(w time.Weekday) string {
	hari := []string{"MIN", "SEN", "SEL", "RAB", "KAM", "JUM", "SAB"}
	return hari[w]
}

// StartMissedDoseChecker akan berjalan di background mengecek obat yang diabaikan
func StartMissedDoseChecker(db *gorm.DB) {
	fmt.Println("🚀 Background Worker: Auto-Missed Checker berjalan (Mode Testing)...")

	go func() {
		for {
			// ✅ TESTING: Looping berjalan setiap 30 Detik agar cepat merespon
			time.Sleep(30 * time.Second)

			now := time.Now()
			hariIni := getHariPendek(now.Weekday())

			var jadwalHariIni []models.JadwalObat
			// Cari jadwal yang mengandung singkatan hari ini (misal "SEN")
			db.Where("hari LIKE ?", "%"+hariIni+"%").Find(&jadwalHariIni)

			for _, jadwal := range jadwalHariIni {
				if jadwal.WaktuMinumObat == nil {
					continue
				}

				jamJadwal := time.Time(*jadwal.WaktuMinumObat)

				// Bentuk jadwal target untuk hari ini
				targetWaktu := time.Date(now.Year(), now.Month(), now.Day(), jamJadwal.Hour(), jamJadwal.Minute(), 0, 0, now.Location())
				
				// ✅ TESTING: Batas toleransi jadi 3 Menit (Alarm + Snooze 2 Menit + 1 Menit)
				batasToleransi := targetWaktu.Add(3 * time.Minute)

				// Jika waktu sekarang SUDAH MELEWATI batas toleransi
				if now.After(batasToleransi) {
					var count int64
					todayStr := now.Format("2006-01-02")
					
					// Cek apakah sudah ada input (Diminum/Dilewati) oleh user hari ini
					db.Model(&models.LogKonsumsiObat{}).
						Where("id_jadwal_obat = ? AND DATE(tgl_konsumsi) = ?", jadwal.IDJadwalObat, todayStr).
						Count(&count)

					// Jika kosong (Berarti Notifikasi diabaikan begitu saja)
					if count == 0 {
						tglCustom := models.CustomDate(now)
						logBaru := models.LogKonsumsiObat{
							IDJadwalObat: jadwal.IDJadwalObat,
							TglKonsumsi:  &tglCustom,
							Status:       "Terlewat",
						}
						
						if err := db.Create(&logBaru).Error; err == nil {
							fmt.Printf("⚠️ Auto-Worker: Jadwal %d otomatis ditandai 'Terlewat'.\n", jadwal.IDJadwalObat)
						}
					}
				}
			}
		}
	}()
}