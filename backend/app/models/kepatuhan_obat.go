package models

type HasilKepatuhanObat struct {
	IDObat          uint     `json:"id_obat"`
	NamaObat        string   `json:"nama_obat"`
	StatDiminum     int      `json:"stat_diminum"`
	StatTotal       int      `json:"stat_total"`
	StatusLog       []string `json:"status_log"`
	StatusKepatuhan string   `json:"status_kepatuhan"`
	PesanEdukasi    string   `json:"pesan_edukasi"`
}
