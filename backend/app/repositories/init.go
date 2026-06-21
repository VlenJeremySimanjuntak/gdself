package repositories

import (
	"monitoring-service/pkg/config"

	"gorm.io/gorm"
)

// Exposed DB instance for transactional operations in higher layers
var DB *gorm.DB

type Main struct {
	User          UserRepository
	OTP           OTPRepository // ✅ BARU: Repository untuk OTP
	Riwayat       RiwayatRepository
	LaporanLab    LaporanLabRepository
	Obat          ObatRepository
	Wearable      WearableRepository
	HasilLab      HasilLabRepository
	Parameter     ParameterRepository
	JadwalObat    JadwalObatRepository
	LogKonsumsi   LogKonsumsiRepository
	Lab           LabRepository // Untuk backward compatibility dengan lab operations

	// Repository AI yang sudah dipecah dan USG Tiroid
	HasilAIHarian HasilAIHarianRepository
	HasilAILab    HasilAILabRepository
	HasilAITren   HasilAITrenRepository
	UsgTiroid     UsgTiroidRepository
}

type Options struct {
	Config *config.Config
	DB     *gorm.DB
}

func Init(opts Options) *Main {
	// save DB reference for package-level access (used for transactions)
	DB = opts.DB
	return &Main{
		User:          NewUserRepository(opts.DB),
		OTP:           NewOTPRepository(opts.DB), // ✅ BARU: Inisialisasi OTP
		Riwayat:       NewRiwayatRepository(opts.DB),
		LaporanLab:    NewLaporanLabRepository(opts.DB),
		Obat:          NewObatRepository(opts.DB),
		Wearable:      NewWearableRepository(opts.DB),
		HasilLab:      NewHasilLabRepository(opts.DB),
		Parameter:     NewParameterRepository(opts.DB),
		JadwalObat:    NewJadwalObatRepository(opts.DB),
		LogKonsumsi:   NewLogKonsumsiRepository(opts.DB),
		Lab:           NewLabRepository(opts.DB), // Untuk backward compatibility

		// Inisialisasi instance repository baru
		HasilAIHarian: NewHasilAIHarianRepository(opts.DB),
		HasilAILab:    NewHasilAILabRepository(opts.DB),
		HasilAITren:   NewHasilAITrenRepository(opts.DB),
		UsgTiroid:     NewUsgTiroidRepository(opts.DB),
	}
}