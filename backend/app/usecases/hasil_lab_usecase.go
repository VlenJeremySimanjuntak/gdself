package usecases

import (
	"fmt"
	"strings"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type HasilLabUsecase interface {
	CreateHasilLab(input models.CreateHasilLabRequest) (models.HasilLab, error)
	GetHasilLabByID(id uint) (models.HasilLab, error)
	GetHasilLabByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error)
	GetHasilLabByRiwayatID(riwayatID uint) ([]models.HasilLab, error)
	GetHasilLabByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error)
	GetLaporanByUserAndDate(userID uint, date string) (models.LaporanLab, error)
	GetAllHasilLab() ([]models.HasilLab, error)
	UpdateHasilLab(id uint, input models.UpdateHasilLabRequest) (models.HasilLab, error)
	DeleteHasilLab(id uint) error
}

type hasilLabUsecase struct {
	repoHasilLab   repositories.HasilLabRepository
	repoParameter  repositories.ParameterRepository
	repoLaporanLab repositories.LaporanLabRepository
	repoWearable   repositories.WearableRepository
	repoHasilAI    repositories.HasilAIRepository
}

func NewHasilLabUsecase(
	repoHasilLab repositories.HasilLabRepository,
	repoParameter repositories.ParameterRepository,
	repoLaporan repositories.LaporanLabRepository,
	repoWearable repositories.WearableRepository,
	repoHasilAI repositories.HasilAIRepository,
) HasilLabUsecase {
	return &hasilLabUsecase{
		repoHasilLab:   repoHasilLab,
		repoParameter:  repoParameter,
		repoLaporanLab: repoLaporan,
		repoWearable:   repoWearable,
		repoHasilAI:    repoHasilAI,
	}
}

func (u *hasilLabUsecase) CreateHasilLab(input models.CreateHasilLabRequest) (models.HasilLab, error) {
	// Start DB transaction
	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return models.HasilLab{}, tx.Error
	}

	// Ensure rollback on error/panic
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Validate parameters
	if len(input.Parameters) == 0 {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("minimal 1 parameter harus diisi")
	}

	// 1) Find or create riwayat for today (anchor)
	if input.IDUser == 0 {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("id_user harus diisi untuk membuat riwayat")
	}
	now := time.Now()
	dateOnly := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	today := models.CustomDate(dateOnly)

	var riwayat models.Riwayat
	if err := tx.Where("id_user = ? AND tanggal = ?", input.IDUser, today).First(&riwayat).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			// create
			r := models.Riwayat{
				IDUser:  input.IDUser,
				Tanggal: &today,
			}
			if err := tx.Create(&r).Error; err != nil {
				tx.Rollback()
				return models.HasilLab{}, fmt.Errorf("gagal membuat riwayat: %v", err)
			}
			riwayat = r
		} else {
			tx.Rollback()
			return models.HasilLab{}, err
		}
	}
	input.IDRiwayat = riwayat.IDRiwayat

	// 2) Create or use laporan lab
	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		if input.NamaLab == "" {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nama_lab harus diisi ketika membuat laporan baru")
		}
		laporan := models.LaporanLab{
			IDRiwayat:  riwayat.IDRiwayat,
			IDUser:     input.IDUser,
			NamaLab:    input.NamaLab,
			TglPeriksa: &today,
		}
		if err := tx.Create(&laporan).Error; err != nil {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("gagal membuat laporan lab: %v", err)
		}
		idLaporan = laporan.IDLaporanLab
	}

	var firstCreatedID uint
	var hasilLabs []models.HasilLab // Array untuk menampung hasil lab yang baru di-insert

	// 3) Loop parameters and create hasil_lab records using tx
	for _, param := range input.Parameters {
		paramName := strings.TrimSpace(param.NamaParameter)
		if paramName == "" {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nama_parameter tidak boleh kosong")
		}

		// Try get master param using tx
		var masterParam models.Parameter
		err := tx.Where("LOWER(nama_parameter) = LOWER(?)", paramName).First(&masterParam).Error
		if err != nil {
			if err == gorm.ErrRecordNotFound {
				masterParam = models.Parameter{
					NamaParameter: strings.ToUpper(paramName),
					Satuan:        param.Satuan,
					Kategori:      param.Kategori,
				}
				if err := tx.Create(&masterParam).Error; err != nil {
					tx.Rollback()
					return models.HasilLab{}, fmt.Errorf("gagal membuat master parameter %s: %v", paramName, err)
				}
			} else {
				tx.Rollback()
				return models.HasilLab{}, err
			}
		}

		// Determine nilai
		nilai := param.Nilai
		if nilai == 0 {
			nilai = param.NilaiHasil
		}
		if nilai == 0 {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nilai untuk parameter %s harus diisi", paramName)
		}

		// rujukan
		rujukanMin := param.RujukanMin
		rujukanMax := param.RujukanMax

		created := models.HasilLab{
			IDLaporanLab: idLaporan,
			IDRiwayat:    riwayat.IDRiwayat,
			IDParameter:  masterParam.IDParameter,
			NilaiHasil:   nilai,
			RujukanMin:   rujukanMin,
			RujukanMax:   rujukanMax,
			Parameter:    &masterParam, // Inject relasi parameter untuk kalkulasi skor di bawah
		}

		if err := tx.Create(&created).Error; err != nil {
			tx.Rollback()
			return models.HasilLab{}, err
		}

		hasilLabs = append(hasilLabs, created) // Kumpulkan untuk dihitung skornya nanti

		if firstCreatedID == 0 {
			firstCreatedID = created.IDHasilLab
		}
	}

	if firstCreatedID == 0 {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("gagal membuat hasil lab")
	}

	// =================================================================
	// 4) AMBIL WEARABLE TERBARU HARI INI
	// =================================================================
	var latestWearable models.WearableRecord
	var wearableFound bool
	var idWearable *uint 

	if err := tx.Where("id_riwayat = ?", riwayat.IDRiwayat).
		Order("tgl_data DESC, waktu_data DESC").
		First(&latestWearable).Error; err == nil {
		wearableFound = true
		wID := uint(latestWearable.IDWearable) 
		idWearable = &wID
	}

	// Ambil score AI harian dari wearable (jika ada) - Masih Skala 0-100 (High is Good)
	var wearableAIScore100 float64
	if wearableFound {
		var harian models.HasilAIHarian
		if err := tx.Where("id_wearable = ?", latestWearable.IDWearable).
			Order("tgl_hasil_ai DESC").
			First(&harian).Error; err == nil {
			wearableAIScore100 = harian.Score
		}
	}

	// 👇 BARU: Konversi Skor AI Harian (0-100 High Good) ke Kategori Wearable (1-3 Low Good)
	// Asumsi: Skor 0-100 di AI Harian adalah High=Good.
	// Tabel Mas Vlen minta Kategori: 1=Normal(Good), 2=Sedang, 3=BelumNormal(Bad).
	kategoriWearable3 := float64(3) // Default terburuk jika tidak ada data
	if wearableFound {
		if wearableAIScore100 >= 70 { // Skor tinggi di jam tangan
			kategoriWearable3 = 1 // Normal (Sesuai image_5.png No 1-3)
		} else if wearableAIScore100 >= 40 {
			kategoriWearable3 = 2 // Sedang (Sesuai image_5.png No 2, 5, 8)
		} else {
			kategoriWearable3 = 3 // Belum Normal (Sesuai image_5.png No 3, 6, image_6.png No 9)
		}
	}

	// =================================================================
	// 5) 👇 BARU: HITUNG SKOR LAB BERDASARKAN KATEGORI (Skala 1-3)
	// =================================================================
	
	// Fungsi pembantu baru untuk menentukan Kategori Lab (1=Normal, 2=Belum Normal, 3=Tidak Diketahui/Buruk)
	kategoriLabFor := func(name string, value float64) float64 {
		n := strings.ToLower(name)
		
		// Aturan Rule-Based Sederhana untuk menentukan Kategori 1, 2, atau 3
		switch {
		case strings.Contains(n, "tsh"):
			// Ideal 0.4 - 4.0
			if value >= 0.4 && value <= 4.0 {
				return 1 // Normal (Kategori Lab 1 sesuai image_5.png)
			}
			// Batas Belum Normal (sedikit di luar range ideal)
			if value >= 0.1 && value <= 10.0 {
				return 2 // Belum Normal (Kategori Lab 2 sesuai image_5.png)
			}
			return 3 // Tidak Diketahui / Parah (Kategori Lab 3 sesuai image_5.png)
			
		case strings.Contains(n, "ft3"):
			// approximate ideal 2.3 - 4.2
			if value >= 2.3 && value <= 4.2 {
				return 1 // Normal
			}
			if value >= 1.5 && value <= 6.0 {
				return 2 // Belum Normal
			}
			return 3 // Tidak Diketahui

		case strings.Contains(n, "ft4"):
			// approximate ideal 0.8 - 1.8
			if value >= 0.8 && value <= 1.8 {
				return 1 // Normal
			}
			if value >= 0.5 && value <= 2.5 {
				return 2 // Belum Normal
			}
			return 3 // Tidak Diketahui

		default:
			return 3 // Parameter lain dianggap Tidak Diketahui jika tidak diatur
		}
	}

	var sumKategoriLab float64
	var countParams float64
	// Loop menggunakan hasilLabs yang baru saja di-insert
	for _, hl := range hasilLabs {
		pname := ""
		if hl.Parameter != nil {
			pname = hl.Parameter.NamaParameter
		}
		kat := kategoriLabFor(pname, hl.NilaiHasil)
		sumKategoriLab += kat
		countParams += 1
	}
	
	// Hitung rata-rata Kategori Lab (Skala 1-3 Low is Good)
	var rerataKategoriLab float64
	if countParams > 0 {
		rerataKategoriLab = sumKategoriLab / countParams
	} else {
		rerataKategoriLab = 3 // Default terburuk
	}

	// =================================================================
	// 6) 👇 BARU: FINAL SCORE WITH 70-30 WEIGHTING (Skala 1.0 - 3.0) Low is Good
	// =================================================================

	finalScore1to3 := (rerataKategoriLab * 0.7) + (kategoriWearable3 * 0.3)

	kesimpulan := "Tidak Diketahui"
	if finalScore1to3 <= 1.6 { // 1.0 - 1.6 (Normal sesuai image_5.png No 1-3)
		kesimpulan = "Normal"
	} else if finalScore1to3 <= 2.3 { // 1.7 - 2.3 (Belum Normal sesuai image_5.png No 4-6)
		kesimpulan = "Belum Normal"
	} else { // 2.4 - 3.0 (Tidak Diketahui sesuai image_5.png No 7-8, image_6.png No 9)
		kesimpulan = "Tidak Diketahui"
	}

	var laporanAll []models.LaporanLab
	if err := tx.Where("id_user = ?", input.IDUser).Preload("HasilLab.Parameter").Find(&laporanAll).Error; err != nil {
		laporanAll = nil
	}

	var currentMonthAvg, prevMonthAvg float64
	var currentCount, prevCount float64
	riwayatTime := time.Time(*riwayat.Tanggal)
	curYear, curMonth, _ := riwayatTime.Date()
	prev := riwayatTime.AddDate(0, -1, 0)
	prevYear, prevMonth, _ := prev.Date()
	
	for _, lp := range laporanAll {
		if lp.TglPeriksa == nil {
			continue
		}
		t := time.Time(*lp.TglPeriksa)
		y, m, _ := t.Date()
		
		var ssum float64
		var scnt float64
		for _, h := range lp.HasilLab {
			pname := ""
			if h.Parameter != nil {
				pname = h.Parameter.NamaParameter
			}
			// Menghitung tren menggunakan skala kategori harian (1.0 - 3.0)
			ssum += kategoriLabFor(pname, h.NilaiHasil)
			scnt += 1
		}
		if scnt == 0 {
			continue
		}
		lapScore := ssum / scnt
		if y == curYear && m == curMonth {
			currentMonthAvg += lapScore
			currentCount += 1
		}
		if y == prevYear && m == prevMonth {
			prevMonthAvg += lapScore
			prevCount += 1
		}
	}
	
	var trendReport string
	arah := "STABIL" // Tarik ke sini deklarasinya dengan ':=' agar aman dari error scope compiler
	
	if currentCount > 0 {
		currentMonthAvg = currentMonthAvg / currentCount
		if prevCount > 0 {
			prevMonthAvg = prevMonthAvg / prevCount
			trendReport = fmt.Sprintf("Rata-rata kategori lab bulan ini: %.2f vs bulan lalu: %.2f", currentMonthAvg, prevMonthAvg)
			
			// Evaluasi arah perubahan skala 1.0 - 3.0 (Makin kecil makin bagus)
			diff := currentMonthAvg - prevMonthAvg
			if diff < -0.1 { // Nilai menurun = kondisi membaik
				arah = "MEMBAIK"
			} else if diff > 0.1 { // Nilai meningkat = kondisi memburuk
				arah = "MEMBURUK"
			}
		} else {
			trendReport = fmt.Sprintf("Rata-rata kategori lab bulan ini: %.2f (tidak ada data bulan lalu)", currentMonthAvg)
		}
	} else {
		trendReport = "Tidak cukup data untuk menentukan tren"
	}

	// =================================================================
	// 8) INSERT KE HASIL AI GABUNGAN (Use tx)
	// =================================================================
	firstIDUint := uint(firstCreatedID)
	h2 := models.HasilAIGabungan{
		IDHasilLab:    &firstIDUint,
		IDRiwayat:     uint(riwayat.IDRiwayat),
		IDWearable:    idWearable, // Terisi *uint jika ditemukan, NULL jika tidak
		TglHasilAI:    time.Now(),
		
		// 👇 BARU: Simpan Skor Skala 1.0 - 3.0 (Low is Good)
		Score:         finalScore1to3, 
		
		// 👇 BARU: Simpan Status berdasarkan kriteria TA Mas Vlen
		KesimpulanLab: kesimpulan, 
		
		TrendReport:   trendReport,
		ArahPerubahan: arah,
		IsRead:        false,
	}

	if err := tx.Create(&h2).Error; err != nil {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("gagal menyimpan hasil AI gabungan: %v", err)
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		tx.Rollback()
		return models.HasilLab{}, err
	}

	return u.repoHasilLab.GetByID(firstCreatedID)
}

func (u *hasilLabUsecase) GetHasilLabByID(id uint) (models.HasilLab, error) {
	if id == 0 {
		return models.HasilLab{}, fmt.Errorf("id tidak valid")
	}

	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return models.HasilLab{}, fmt.Errorf("hasil lab tidak ditemukan")
	}

	return hasilLab, nil
}

func (u *hasilLabUsecase) GetHasilLabByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error) {
	if laporanLabID == 0 {
		return nil, fmt.Errorf("laporan_lab_id tidak valid")
	}

	return u.repoHasilLab.GetByLaporanLabID(laporanLabID)
}

func (u *hasilLabUsecase) GetHasilLabByRiwayatID(riwayatID uint) ([]models.HasilLab, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}

	return u.repoHasilLab.GetByRiwayatID(riwayatID)
}

func (u *hasilLabUsecase) GetHasilLabByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}
	if strings.TrimSpace(date) == "" {
		return nil, fmt.Errorf("tanggal tidak valid")
	}

	return u.repoHasilLab.GetByRiwayatIDAndDate(riwayatID, date)
}

func (u *hasilLabUsecase) GetLaporanByUserAndDate(userID uint, date string) (models.LaporanLab, error) {
	if userID == 0 {
		return models.LaporanLab{}, fmt.Errorf("user_id tidak valid")
	}
	if strings.TrimSpace(date) == "" {
		return models.LaporanLab{}, fmt.Errorf("tanggal tidak valid")
	}

	laporan, err := u.repoLaporanLab.GetByUserIDAndDate(userID, date)
	if err != nil {
		return models.LaporanLab{}, fmt.Errorf("data tidak ditemukan")
	}
	if laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("data tidak ditemukan")
	}
	return laporan, nil
}

func (u *hasilLabUsecase) GetAllHasilLab() ([]models.HasilLab, error) {
	return u.repoHasilLab.GetAll()
}

func (u *hasilLabUsecase) UpdateHasilLab(id uint, input models.UpdateHasilLabRequest) (models.HasilLab, error) {
	if id == 0 {
		return models.HasilLab{}, fmt.Errorf("id tidak valid")
	}

	// Get existing hasil lab
	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return models.HasilLab{}, fmt.Errorf("hasil lab tidak ditemukan")
	}

	// Update only non-empty/non-zero fields
	if input.NilaiHasil != 0 {
		hasilLab.NilaiHasil = input.NilaiHasil
	}
	if input.RujukanMin != 0 {
		hasilLab.RujukanMin = input.RujukanMin
	}
	if input.RujukanMax != 0 {
		hasilLab.RujukanMax = input.RujukanMax
	}

	return u.repoHasilLab.Update(id, hasilLab)
}

func (u *hasilLabUsecase) DeleteHasilLab(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if hasil lab exists
	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return fmt.Errorf("hasil lab tidak ditemukan")
	}

	// Delete parameters first (cascade delete should handle this, but explicit is safer)
	// Then delete hasil lab
	return u.repoHasilLab.Delete(id)
}