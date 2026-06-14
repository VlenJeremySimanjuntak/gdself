package models

import "time"

type HasilLab struct {
	IDHasilLab   uint `json:"id_hasil_lab" gorm:"column:id_hasil_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDLaporanLab uint `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;not null;index"`
	// Backwards-compatible fields (not persisted here; linked via LaporanLab)
	IDRiwayat   uint        `json:"id_riwayat,omitempty" gorm:"-"`
	TglPeriksa  *CustomDate `json:"tgl_periksa,omitempty" gorm:"-"`
	IDParameter uint        `json:"id_parameter" gorm:"column:id_parameter;type:int unsigned;not null;index"`
	NilaiHasil  float64     `json:"nilai_hasil" gorm:"column:nilai_hasil"`
	RujukanMin  float64     `json:"rujukan_min" gorm:"column:rujukan_min"`
	RujukanMax  float64     `json:"rujukan_max" gorm:"column:rujukan_max"`
	CreatedAt   time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	// Relationships
	LaporanLab *LaporanLab       `json:"laporan_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Parameter  *Parameter        `json:"parameter,omitempty" gorm:"foreignKey:IDParameter;references:IDParameter;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT"`
	HasilAI    []HasilAIGabungan `json:"hasil_ai,omitempty" gorm:"foreignKey:IDHasilLab;references:IDHasilLab;constraint:OnUpdate:CASCADE,OnDelete:SET NULL"`

	// For assessment payload compatibility only.
	Parameters []Parameter `json:"parameters,omitempty" gorm:"-"`
}

func (HasilLab) TableName() string {
	return "hasil_lab"
}

// DTO untuk Create Hasil Lab dengan Parameters
type CreateHasilLabRequest struct {
	IDReport     uint                     `json:"id_report,omitempty"`
	IDLaporanLab uint                     `json:"id_laporan_lab,omitempty"`
	IDRiwayat    uint                     `json:"id_riwayat,omitempty"`
	NilaiHasil   float64                  `json:"nilai_hasil"`
	RujukanMin   float64                  `json:"rujukan_min,omitempty"`
	RujukanMax   float64                  `json:"rujukan_max,omitempty"`
	IDUser       uint                     `json:"id_user,omitempty"`
	NamaLab      string                   `json:"nama_lab,omitempty"`
	TglPeriksa   *CustomDate              `json:"tgl_periksa,omitempty"`
	Parameters   []CreateParameterRequest `json:"parameters" binding:"required"`
}

// DTO untuk Update Hasil Lab
type UpdateHasilLabRequest struct {
	NilaiHasil float64 `json:"nilai_hasil"`
	RujukanMin float64 `json:"rujukan_min"`
	RujukanMax float64 `json:"rujukan_max"`
}

// DTO untuk Create Parameter
type CreateParameterRequest struct {
	NamaParameter string  `json:"nama_parameter" binding:"required"`
	Satuan        string  `json:"satuan"`
	Kategori      string  `json:"kategori"`
	Nilai         float64 `json:"nilai,omitempty"`
	NilaiHasil    float64 `json:"nilai_hasil,omitempty"`
	RujukanMin    float64 `json:"rujukan_min,omitempty"`
	RujukanMax    float64 `json:"rujukan_max,omitempty"`
}
