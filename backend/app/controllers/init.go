package controllers

import (
	"monitoring-service/app/repositories"
	"monitoring-service/app/usecases"
	"monitoring-service/pkg/config"
)

type Main struct {
	User          UserController
	Auth          AuthController
	Riwayat       RiwayatController
	LaporanLab    LaporanLabController
	Monitoring    MonitoringController
	Obat          ObatController
	KepatuhanObat KepatuhanObatController
	Wearable      WearableController
	HasilLab      HasilLabController
	HasilAI       HasilAIController
	JadwalObat    JadwalObatController
	LogKonsumsi   LogKonsumsiController
	Lab           LabController
	USGTiroid     USGTiroidController
}

type Options struct {
	Config       *config.Config
	UseCases     *usecases.Main
	Repositories *repositories.Main
}

func Init(opts Options) *Main {
	return &Main{
		User:          NewUserController(opts.UseCases.User),
		Auth:          NewAuthController(opts.UseCases.Auth, opts.UseCases.User),
		Riwayat:       NewRiwayatController(opts.UseCases.Riwayat),
		LaporanLab:    NewLaporanLabController(opts.UseCases.LaporanLab),
		Monitoring:    NewMonitoringController(opts.UseCases.LaporanLab, opts.UseCases.Lab),
		Obat:          NewObatController(opts.UseCases.Obat),
		KepatuhanObat: NewKepatuhanObatController(opts.UseCases.KepatuhanObat),
		Wearable:      NewWearableController(opts.UseCases.Wearable),
		HasilLab:      NewHasilLabController(opts.UseCases.HasilLab, opts.UseCases.Lab, opts.Repositories.LaporanLab), // ✅ tambah repo
		HasilAI:       NewHasilAIController(opts.UseCases.HasilAIHarian, opts.UseCases.HasilAILab, opts.UseCases.HasilAITren, opts.UseCases.Lab),
		JadwalObat:    NewJadwalObatController(opts.UseCases.JadwalObat),
		LogKonsumsi:   NewLogKonsumsiController(opts.UseCases.LogKonsumsi),
		Lab:           NewLabController(opts.UseCases.Lab),
		USGTiroid:     NewUSGTiroidController(opts.UseCases.UsgTiroid),
	}
}
