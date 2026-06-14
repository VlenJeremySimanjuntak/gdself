package controllers

import (
	"monitoring-service/app/usecases"
	"monitoring-service/pkg/config"
)

type Main struct {
	User       UserController
	Riwayat    RiwayatController
	LaporanLab LaporanLabController
	Monitoring MonitoringController
	Obat       ObatController
	Wearable   WearableController
	HasilLab   HasilLabController
	HasilAI    HasilAIController
	JadwalObat JadwalObatController
	Lab        LabController // Untuk backward compatibility dengan lab operations
}

type Options struct {
	Config   *config.Config
	UseCases *usecases.Main
}

func Init(opts Options) *Main {
	return &Main{
		User:       NewUserController(opts.UseCases.User),
		Riwayat:    NewRiwayatController(opts.UseCases.Riwayat),
		LaporanLab: NewLaporanLabController(opts.UseCases.LaporanLab),
		Monitoring: NewMonitoringController(opts.UseCases.LaporanLab),
		Obat:       NewObatController(opts.UseCases.Obat),
		Wearable:   NewWearableController(opts.UseCases.Wearable),
		HasilLab:   NewHasilLabController(opts.UseCases.HasilLab),
		HasilAI:    NewHasilAIController(opts.UseCases.HasilAI),
		JadwalObat: NewJadwalObatController(opts.UseCases.JadwalObat),
		Lab:        NewLabController(opts.UseCases.Lab), // Untuk backward compatibility
	}
}
