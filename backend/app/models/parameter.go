package models

type Parameter struct {
	IDParameter   uint   `json:"id_parameter" gorm:"column:id_parameter;type:int unsigned;primaryKey;autoIncrement"`
	NamaParameter string `json:"nama_parameter" gorm:"column:nama_parameter;size:100;not null;uniqueIndex"`
	Satuan        string `json:"satuan" gorm:"column:satuan;size:50"`
	Kategori      string `json:"kategori" gorm:"column:kategori;size:50"`

	// Legacy payload fields used by assessment/input compatibility.
	IDHasilLab uint    `json:"id_hasil_lab,omitempty" gorm:"-"`
	Nilai      float64 `json:"nilai,omitempty" gorm:"-"`
}

func (Parameter) TableName() string {
	return "parameter"
}
