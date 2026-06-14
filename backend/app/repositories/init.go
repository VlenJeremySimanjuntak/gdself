package repositories

import (
	"monitoring-service/pkg/config"

	"gorm.io/gorm"
)

// Exposed DB instance for transactional operations in higher layers
var DB *gorm.DB

type Main struct {
	User       UserRepository
	Riwayat    RiwayatRepository
	LaporanLab LaporanLabRepository
	Obat       ObatRepository
	Wearable   WearableRepository
	HasilLab   HasilLabRepository
	Parameter  ParameterRepository
	HasilAI    HasilAIRepository
	JadwalObat JadwalObatRepository
	Lab        LabRepository // Untuk backward compatibility dengan lab operations
}

type Options struct {
	Config *config.Config
	DB     *gorm.DB
}

func Init(opts Options) *Main {
	// save DB reference for package-level access (used for transactions)
	DB = opts.DB
	return &Main{
		User:       NewUserRepository(opts.DB),
		Riwayat:    NewRiwayatRepository(opts.DB),
		LaporanLab: NewLaporanLabRepository(opts.DB),
		Obat:       NewObatRepository(opts.DB),
		Wearable:   NewWearableRepository(opts.DB),
		HasilLab:   NewHasilLabRepository(opts.DB),
		Parameter:  NewParameterRepository(opts.DB),
		HasilAI:    NewHasilAIRepository(opts.DB),
		JadwalObat: NewJadwalObatRepository(opts.DB),
		Lab:        NewLabRepository(opts.DB), // Untuk backward compatibility
	}
}
