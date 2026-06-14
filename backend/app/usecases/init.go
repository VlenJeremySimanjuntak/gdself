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
	HasilAI    HasilAIUsecase
	JadwalObat JadwalObatUsecase
	Lab        LabUsecase // Untuk backward compatibility dengan lab operations
}

type Options struct {
	Repository *repositories.Main
	Config     *config.Config
}

func Init(opts Options) *Main {
	return &Main{
		User:       NewUserUsecase(opts.Repository.User),
		Riwayat:    NewRiwayatUsecase(opts.Repository.Riwayat),
		LaporanLab: NewLaporanLabUsecase(opts.Repository.LaporanLab),
		Obat:       NewObatUsecase(opts.Repository.Obat),
		Wearable:   NewWearableUsecase(opts.Repository.Wearable),
		HasilLab:   NewHasilLabUsecase(opts.Repository.HasilLab, opts.Repository.Parameter, opts.Repository.LaporanLab, opts.Repository.Wearable, opts.Repository.HasilAI),
		HasilAI:    NewHasilAIUsecase(opts.Repository.HasilAI),
		JadwalObat: NewJadwalObatUsecase(opts.Repository.JadwalObat),
		Lab:        NewLabUsecase(opts.Repository.Lab, opts.Repository.Parameter, NewHasilAIUsecase(opts.Repository.HasilAI)), // Wire HasilAI for assessment persistence
	}
}
