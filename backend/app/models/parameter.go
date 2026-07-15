package models

type Parameter struct {
	IDParameter   uint   `json:"id_parameter" gorm:"column:id_parameter;type:int unsigned;primaryKey;autoIncrement"`
	NamaParameter string `json:"nama_parameter" gorm:"column:nama_parameter;size:100;not null;uniqueIndex"`
	Satuan        string `json:"satuan" gorm:"column:satuan;size:50"`
	Kategori      string `json:"kategori" gorm:"column:kategori;size:50"`
	TipeRujukan   string `json:"tipe_rujukan" gorm:"column:tipe_rujukan;size:50"` // Sesuai dengan ERD terbaru

	// Relasi ini tetap ada untuk Preload, tetapi tidak ikut membangun schema saat migrasi.
	HasilLabs []HasilLab `json:"hasil_labs,omitempty" gorm:"foreignKey:IDParameter;references:IDParameter;-:migration"`

	// Legacy payload fields used by assessment/input compatibility.
	IDHasilLab uint    `json:"id_hasil_lab,omitempty" gorm:"-"`
	Nilai      float64 `json:"nilai,omitempty" gorm:"-"`
}

func (Parameter) TableName() string {
	return "parameter"
}

// DTO Parameter
type CreateParameterRequest struct {
	NamaParameter   string  `json:"nama_parameter" binding:"required"`
	Satuan          string  `json:"satuan"`
	Kategori        string  `json:"kategori"`
	Nilai           float64 `json:"nilai,omitempty"`
	NilaiHasil      float64 `json:"nilai_hasil,omitempty"`
	NilaiBatasBawah float64 `json:"nilai_batas_bawah,omitempty"`
	NilaiBatasAtas  float64 `json:"nilai_batas_atas,omitempty"`
}
