package models

// Tambahan struct untuk menyimpan riwayat tanggal dan jam yang akan dibaca Flutter
type DetailLogKonsumsi struct {
	Tanggal string `json:"tanggal"`
	Jam     string `json:"jam"`
	Status  string `json:"status"`
}

type HasilNotifikasiObat struct {
	IDObat          uint                `json:"id_obat"`
	NamaObat        string              `json:"nama_obat"`
	Detail          []DetailLogKonsumsi `json:"detail"` // Dulu StatusLog ([]string)
	Status          string              `json:"status,omitempty"`
	PerluNotifikasi bool                `json:"perlu_notifikasi"`
	Ringkasan       string              `json:"ringkasan,omitempty"` // Dulu Pesan (disamakan dgn frontend)
}

type HasilKepatuhanObat struct {
	IDObat          uint    `json:"id_obat"`
	NamaObat        string  `json:"nama_obat"`
	StatDiminum     int     `json:"stat_diminum"`
	StatTotal       int     `json:"stat_total"`
	Persentase      float64 `json:"persentase"`
	StatusKepatuhan string  `json:"status_kepatuhan"`
	PesanEdukasi    string  `json:"pesan_edukasi"`
}