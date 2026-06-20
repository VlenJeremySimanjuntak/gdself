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

			// 2. AMBIL WAKTU SEKARANG BERDASARKAN JAM JAKARTA
			now := time.Now().In(loc)
			hariIni := getHariPendek(now.Weekday())

			// Log untuk memantau apakah worker benar-benar jalan
			fmt.Printf("\n🔎 [Worker Cek] Jam Server: %s WIB | Hari: %s\n", now.Format("15:04:05"), hariIni)

			var jadwalHariIni []models.JadwalObat
			db.Where("hari LIKE ?", "%"+hariIni+"%").Find(&jadwalHariIni)

			fmt.Printf("   -> Ditemukan %d jadwal obat untuk hari %s\n", len(jadwalHariIni), hariIni)

			for _, jadwal := range jadwalHariIni {
				if jadwal.WaktuMinumObat == nil {
					continue
				}

				jamJadwal := time.Time(*jadwal.WaktuMinumObat)

				// Bentuk jadwal target menggunakan jam dan menit dari DB + Tanggal hari ini
				targetWaktu := time.Date(now.Year(), now.Month(), now.Day(), jamJadwal.Hour(), jamJadwal.Minute(), 0, 0, loc)
				
				// TESTING: Batas toleransi 3 Menit
				batasToleransi := targetWaktu.Add(3 * time.Minute)

				fmt.Printf("   -> ID Jadwal: %d | Waktu Obat: %s | Batas Toleransi: %s\n", 
					jadwal.IDJadwalObat, 
					targetWaktu.Format("15:04"), 
					batasToleransi.Format("15:04"))

				// Jika waktu sekarang SUDAH MELEWATI batas toleransi
				if now.After(batasToleransi) {
					var count int64
					todayStr := now.Format("2006-01-02")
					
					// Cek apakah sudah ada log hari ini
					db.Model(&models.LogKonsumsiObat{}).
						Where("id_jadwal_obat = ? AND DATE(tgl_konsumsi) = ?", jadwal.IDJadwalObat, todayStr).
						Count(&count)

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
							fmt.Printf("❌ [ERROR] Gagal menyimpan ke DB: %v\n", err)
						}
					} else {
						fmt.Printf("   -> Jadwal %d aman (Sudah ada log hari ini).\n", jadwal.IDJadwalObat)
					}
				} else {
					fmt.Printf("   -> Jadwal %d belum melewati batas toleransi.\n", jadwal.IDJadwalObat)
				}
			}
		}
	}()
}