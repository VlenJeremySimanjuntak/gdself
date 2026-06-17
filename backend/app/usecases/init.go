package usecases

import (
	"monitoring-service/app/repositories"
	"monitoring-service/pkg/config"
)

type Main struct {
	User       UserUsecase
	Riwayat    RiwayatUsecase
	LaporanLab LaporanLabUsecase
	Obat       ObatUsecase
	Wearable   WearableUsecase
	HasilLab   HasilLabUsecase
	JadwalObat JadwalObatUsecase
	Lab        LabUsecase // Untuk backward compatibility dengan lab operations

	// ✅ BARU: Usecase AI yang sudah dipecah dan USG Tiroid
	HasilAIHarian HasilAIHarianUsecase
	HasilAILab    HasilAILabUsecase
	HasilAITren   HasilAITrenUsecase
	UsgTiroid     UsgTiroidUsecase
}

type Options struct {
	Repository *repositories.Main
	Config     *config.Config
}

func Init(opts Options) *Main {
	// 1. Inisialisasi Usecase AI baru terlebih dahulu agar bisa di-inject ke Usecase lain
	hasilAIHarian := NewHasilAIHarianUsecase(opts.Repository.HasilAIHarian)
	hasilAILab := NewHasilAILabUsecase(opts.Repository.HasilAILab)
	hasilAITren := NewHasilAITrenUsecase(opts.Repository.HasilAITren)

	return &Main{
		User:       NewUserUsecase(opts.Repository.User),
		Riwayat:    NewRiwayatUsecase(opts.Repository.Riwayat),
		LaporanLab: NewLaporanLabUsecase(opts.Repository.LaporanLab, opts.Repository.Riwayat),
		Obat:       NewObatUsecase(opts.Repository.Obat),
		Wearable:   NewWearableUsecase(opts.Repository.Wearable),
		JadwalObat: NewJadwalObatUsecase(opts.Repository.JadwalObat),

		// 2. Daftarkan Usecase baru ke dalam Main struct
		HasilAIHarian: hasilAIHarian,
		HasilAILab:    hasilAILab,
		HasilAITren:   hasilAITren,
		UsgTiroid:     NewUsgTiroidUsecase(opts.Repository.UsgTiroid),

		// 3. Update parameter injeksi untuk HasilLab dan Lab (menggantikan HasilAI lama)
		HasilLab: NewHasilLabUsecase(opts.Repository.HasilLab, opts.Repository.Parameter, opts.Repository.LaporanLab, opts.Repository.Wearable, hasilAILab, hasilAITren),
		Lab:      NewLabUsecase(opts.Repository.Lab, opts.Repository.Parameter, hasilAILab, hasilAITren),
	}
}
