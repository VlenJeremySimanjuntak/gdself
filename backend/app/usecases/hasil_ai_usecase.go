package usecases

import (
	"fmt"
	"math"
	"time"
	"gorm.io/gorm"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAIUsecase interface {
	GetHasilAIByID(id uint) (models.HasilAI, error)
	GetHasilAIByRiwayatID(riwayatID uint) ([]models.HasilAI, error)
	GetHasilAIByWearableID(wearableID uint) ([]models.HasilAI, error)
	GetHasilAIByHasilLabID(hasilLabID uint) ([]models.HasilAI, error)
	GetAllHasilAI() ([]models.HasilAI, error)
	UpdateIsRead(id uint) (models.HasilAI, error)
	CreateHasilAI(riwayatID uint, wearableID *uint, hasilLabID *uint, score float64) (models.HasilAI, error)
	// ProcessAIAssessment routes input to the appropriate engines and
	// returns a populated models.HasilAI ready to persist.
	ProcessAIAssessment(req AssessRequest) (*models.HasilAI, error)
}

type hasilAIUsecase struct {
	repo repositories.HasilAIRepository
}

func NewHasilAIUsecase(repo repositories.HasilAIRepository) HasilAIUsecase {
	return &hasilAIUsecase{repo: repo}
}

// AssessRequest is the router input for AI processing. It wraps the
// existing models.AssessmentInput with the user id and optional context
// fields.
type AssessRequest struct {
	Input      models.AssessmentInput
	IDUser     uint
	IDWearable *uint
}

// ProcessAIAssessment implements the router logic: decide which engine(s)
// to run based on availability of lab/wearable/previous data, execute
// private engines, and return a composed models.HasilAI.
func (u *hasilAIUsecase) ProcessAIAssessment(req AssessRequest) (*models.HasilAI, error) {
	inp := req.Input

	// determine presence
	isLabDay := inp.IsLabDay
	hasPrevLab := inp.PrevLab != nil && inp.PrevLab.IDHasilLab != 0
	hasWearable := !(inp.Wearable.HR == 0 && inp.Wearable.Stress == 0 && inp.Wearable.SleepMinutes == 0)

	var hasil models.HasilAI
	hasil.IDRiwayat = nil
	hasil.IDWearable = nil
	hasil.IDHasilLab = nil
	
	if req.IDWearable != nil {
		hasil.IDWearable = req.IDWearable
	}
	if isLabDay {
		if inp.Lab.IDRiwayat != 0 {
			hasil.IDRiwayat = &inp.Lab.IDRiwayat
		}
		if inp.Lab.IDHasilLab != 0 {
			hasil.IDHasilLab = &inp.Lab.IDHasilLab
		}
	}
	hasil.IDHasilAI = 0
	if req.IDUser != 0 {
		hasil.IDUser = req.IDUser
	}
	hasil.TglHasilAI = time.Now()

	// Branching router
	if isLabDay {
		score, kesimpulan := u._runMesin1(inp)
		hasil.Score = score
		hasil.KesimpulanLab = kesimpulan

		if hasPrevLab {
			trendReport, arah, flag := u._runMesin3(inp)
			hasil.TrendReport = trendReport
			hasil.ArahPerubahan = arah
			hasil.FlagUrgensi = flag
		}
	} else {
		if hasWearable {
			status, pesan := u._runMesin2(inp)
			hasil.StatusHarian = status
			hasil.PesanHarian = pesan
		} else {
			return nil, fmt.Errorf("data kurang untuk analisis")
		}
	}

	// =================================================================
	// FIX: TRANSAKSI FIND OR CREATE YANG AMAN
	// =================================================================
	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}

	var riwayat models.Riwayat
	
	// Tentukan tanggal: Jika LabDay gunakan tanggal lab, jika tidak gunakan waktu hari ini
	var dateToday models.CustomDate
	if isLabDay && inp.Lab.TglPeriksa != nil {
		dateToday = *inp.Lab.TglPeriksa
	} else {
		// 👇 PERBAIKAN: Nol-kan jam, menit, dan detik agar cocok dengan database (00:00:00)
		now := time.Now()
		dateOnly := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
		dateToday = models.CustomDate(dateOnly)
	}

	// Lakukan pencarian riwayat
	err := tx.Where("id_user = ? AND tanggal = ?", req.IDUser, dateToday).First(&riwayat).Error
	
	if err == gorm.ErrRecordNotFound {
		// Buat baru jika belum ada
		riwayat = models.Riwayat{
			IDUser:  req.IDUser,
			Tanggal: &dateToday,
		}
		if errCreate := tx.Create(&riwayat).Error; errCreate != nil {
			tx.Rollback()
			return nil, fmt.Errorf("gagal membuat riwayat harian: %v", errCreate)
		}
	} else if err != nil {
		tx.Rollback()
		return nil, err
	}

	// Pastikan IDRiwayat terisi
	hasil.IDRiwayat = &riwayat.IDRiwayat

	// Persist result ke tabel hasil_ai
	created, err := u.repo.Create(hasil)
	if err != nil {
		tx.Rollback()
		return &hasil, err
	}
	
	if errCommit := tx.Commit().Error; errCommit != nil {
		return &created, errCommit
	}

	return &created, nil
}

// _runMesin1 computes absolute score from lab (X) and wearable (Z)
// and returns (score, kesimpulanLab).
func (u *hasilAIUsecase) _runMesin1(inp models.AssessmentInput) (float64, string) {
	ft3, ft4, tsh := extractHormoneValues(inp.Lab.Parameters)
	x, _ := computeLabScore(ft3, ft4, tsh)
	z := computeWearableScore(inp.Wearable)

	// Final score formula per spec
	final := (float64(x) * 0.7) + (float64(z) * 0.3)

	// Kesimpulan yang ramah untuk pasien
	var kes string
	switch x {
	case 1:
		kes = "Hasil laboratorium menunjukkan nilai dalam rentang yang diharapkan (mendekati normal)."
	case 2:
		kes = "Terdapat indikasi yang perlu diperhatikan terkait fungsi tiroid (kemungkinan perubahan)."
	default:
		kes = "Hasil tidak konklusif — perlu evaluasi lebih lanjut oleh profesional kesehatan."
	}

	return mathRound(final, 1), kes
}

// _runMesin2 evaluates daily wearable status and returns (status, pesan)
func (u *hasilAIUsecase) _runMesin2(inp models.AssessmentInput) (string, string) {
	w := inp.Wearable
	abnormal := 0
	if !(w.BaselineHRMin == 0 && w.BaselineHRMax == 0) {
		if w.HR < w.BaselineHRMin || w.HR > w.BaselineHRMax {
			abnormal++
		}
	}
	if !(w.BaselineStressMin == 0 && w.BaselineStressMax == 0) {
		if w.Stress < w.BaselineStressMin || w.Stress > w.BaselineStressMax {
			abnormal++
		}
	}
	if !(w.BaselineSleepMin == 0 && w.BaselineSleepMax == 0) {
		if w.SleepMinutes < w.BaselineSleepMin || w.SleepMinutes > w.BaselineSleepMax {
			abnormal++
		}
	}

	switch abnormal {
	case 0:
		return "NORMAL_HARIAN", "Semua indikator wearable berada dalam batas yang diharapkan hari ini."
	case 1:
		return "SATU_INDIKATOR_BELUM_NORMAL", "Satu indikator menunjukkan penyimpangan ringan dibanding baseline."
	case 2:
		return "DUA_INDIKATOR_BELUM_NORMAL", "Dua indikator menunjukkan penyimpangan; perhatikan pola hari berikutnya."
	default:
		return "TIGA_INDIKATOR_BELUM_NORMAL", "Semua indikator menunjukkan penyimpangan; disarankan untuk berkonsultasi jika berlanjut."
	}
}

// _runMesin3 compares current lab+wearable with previous and returns
// (trendReport, arahPerubahan, flagUrgensi) with less alarming wording.
func (u *hasilAIUsecase) _runMesin3(inp models.AssessmentInput) (string, string, string) {
	// Current
	ft3c, ft4c, tshc := extractHormoneValues(inp.Lab.Parameters)
	xCurr, _ := computeLabScore(ft3c, ft4c, tshc)
	zCurr := computeWearableScore(inp.Wearable)

	// Previous - be defensive if PrevLab is nil or has no parameters
	var xPrev int
	if inp.PrevLab != nil {
		ft3p, ft4p, tshp := extractHormoneValues(inp.PrevLab.Parameters)
		xPrev, _ = computeLabScore(ft3p, ft4p, tshp)
	} else {
		xPrev = xCurr // neutral fallback
	}
	// For previous wearable we try to read from PrevLab's associated wearable if present
	// but input currently doesn't include prev wearable; assume same wearable baseline comparison
	zPrev := zCurr // fallback: if no prev wearable, assume similar (neutral)

	// Compute deltas
	deltaX := xCurr - xPrev
	deltaZ := zCurr - zPrev

	// Determine arah perubahan
	var arah string
	if deltaX < 0 || deltaZ < 0 {
		arah = "Membaik"
	} else if deltaX == 0 && deltaZ == 0 {
		arah = "Tetap serupa"
	} else {
		arah = "Perlu perhatian"
	}

	// Determine flag urgensi in gentle terms
	var flag string
	if deltaX >= 1 || deltaZ >= 1 {
		flag = "Perlu Evaluasi Dokter"
	} else if deltaX == 0 && deltaZ == 0 {
		flag = "Dalam Batas"
	} else {
		flag = "Perlu Perhatian"
	}

	trendReport := fmt.Sprintf("Perbandingan: skor laboratorium dari %d → %d; gejala fisik (wearable) dari %d → %d.", xPrev, xCurr, zPrev, zCurr)

	return trendReport, arah, flag
}

// mathRound rounds to `places` decimal digits.
func mathRound(val float64, places int) float64 {
	shift := math.Pow(10, float64(places))
	return math.Round(val*shift) / shift
}

func (u *hasilAIUsecase) GetHasilAIByID(id uint) (models.HasilAI, error) {
	if id == 0 {
		return models.HasilAI{}, fmt.Errorf("id tidak valid")
	}

	hasilAI, err := u.repo.GetByID(id)
	if err != nil || hasilAI.IDHasilAI == 0 {
		return models.HasilAI{}, fmt.Errorf("hasil AI tidak ditemukan")
	}

	return hasilAI, nil
}

func (u *hasilAIUsecase) GetHasilAIByRiwayatID(riwayatID uint) ([]models.HasilAI, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}

	return u.repo.GetByRiwayatID(riwayatID)
}

func (u *hasilAIUsecase) GetHasilAIByWearableID(wearableID uint) ([]models.HasilAI, error) {
	if wearableID == 0 {
		return nil, fmt.Errorf("wearable_id tidak valid")
	}

	return u.repo.GetByWearableID(wearableID)
}

func (u *hasilAIUsecase) GetHasilAIByHasilLabID(hasilLabID uint) ([]models.HasilAI, error) {
	if hasilLabID == 0 {
		return nil, fmt.Errorf("hasil_lab_id tidak valid")
	}

	return u.repo.GetByHasilLabID(hasilLabID)
}

func (u *hasilAIUsecase) GetAllHasilAI() ([]models.HasilAI, error) {
	return u.repo.GetAll()
}

func (u *hasilAIUsecase) UpdateIsRead(id uint) (models.HasilAI, error) {
	if id == 0 {
		return models.HasilAI{}, fmt.Errorf("id tidak valid")
	}

	// Get existing hasil AI
	hasilAI, err := u.repo.GetByID(id)
	if err != nil || hasilAI.IDHasilAI == 0 {
		return models.HasilAI{}, fmt.Errorf("hasil AI tidak ditemukan")
	}

	// Mark as read
	hasilAI.IsRead = true
	now := time.Now()
	hasilAI.TglKirim = &now

	return u.repo.Update(id, hasilAI)
}

func (u *hasilAIUsecase) CreateHasilAI(riwayatID uint, wearableID *uint, hasilLabID *uint, score float64) (models.HasilAI, error) {
	if riwayatID == 0 {
		return models.HasilAI{}, fmt.Errorf("riwayat_id tidak valid")
	}

	hasilAI := models.HasilAI{
		IDRiwayat:  &riwayatID,
		IDWearable: wearableID,
		IDHasilLab: hasilLabID,
		Score:      score,
		TglHasilAI: time.Now(),
		IsRead:     false,
	}

	return u.repo.Create(hasilAI)
}
