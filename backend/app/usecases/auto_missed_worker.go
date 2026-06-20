package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"gorm.io/gorm"
)

// Fungsi pembantu untuk konversi waktu server ke hari bahasa Indonesia
func getHariIndonesia(w time.Weekday) string {
	hari := []string{"minggu", "senin", "selasa", "rabu", "kamis", "jumat", "sabtu"}
	return hari[w]
}

// StartMissedDoseChecker akan berjalan di background mengecek obat yang diabaikan
func StartMissedDoseChecker(db *gorm.DB) {
	fmt.Println("🚀 Background Worker: Auto-Missed Checker berjalan...")

	go func() {
		for {
			// Looping berjalan setiap 5 menit sekali
			time.Sleep(5 * time.Minute)

			now := time.Now()
			hariIni := getHariIndonesia(now.Weekday())

			var jadwalHariIni []models.JadwalObat
			// Cari jadwal yang mengandung kata hari ini (misal "SENIN")
			db.Where("LOWER(hari) LIKE ?", "%"+hariIni+"%").Find(&jadwalHariIni)

			for _, jadwal := range jadwalHariIni {
				if jadwal.WaktuMinumObat == nil {
					continue
				}

				// Konversi tipe CustomTime milik Mas Vlen ke time.Time bawaan Go
				jamJadwal := time.Time(*jadwal.WaktuMinumObat)

				// Bentuk jadwal target untuk hari ini (jam dan menit dari DB)
				targetWaktu := time.Date(now.Year(), now.Month(), now.Day(), jamJadwal.Hour(), jamJadwal.Minute(), 0, 0, now.Location())
				
				// 💡 Batas waktu telat adalah 15 menit setelah jadwal
				batasToleransi := targetWaktu.Add(15 * time.Minute)

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