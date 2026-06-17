package controllers

import (
	"monitoring-service/app/usecases"
	"monitoring-service/pkg/config"
)

type Main struct {
	User        UserController
	Riwayat     RiwayatController
	LaporanLab  LaporanLabController
	Monitoring  MonitoringController
	Obat        ObatController
	Wearable    WearableController
	HasilLab    HasilLabController
	HasilAI     HasilAIController
	JadwalObat  JadwalObatController
	LogKonsumsi LogKonsumsiController 
	Lab         LabController
	USGTiroid   USGTiroidController
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
		
		Monitoring: NewMonitoringController(
			opts.UseCases.LaporanLab,
			opts.UseCases.Lab,
		),
		
		Obat:     NewObatController(opts.UseCases.Obat),
		Wearable: NewWearableController(opts.UseCases.Wearable),
		HasilLab: NewHasilLabController(opts.UseCases.HasilLab),
		
		HasilAI: NewHasilAIController(
			opts.UseCases.HasilAIHarian,
			opts.UseCases.HasilAILab,
			opts.UseCases.HasilAITren,
			opts.UseCases.Lab,
		),
		
		JadwalObat: NewJadwalObatController(opts.UseCases.JadwalObat),
		LogKonsumsi: NewLogKonsumsiController(opts.UseCases.LogKonsumsi),
		Lab:        NewLabController(opts.UseCases.Lab),
		USGTiroid:  NewUSGTiroidController(opts.UseCases.UsgTiroid),
	}
}