package models

type LaporanLab struct {
	IDLaporanLab uint        `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDRiwayat    uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;index"`
	IDUser       uint        `json:"id_user" gorm:"column:id_user;type:int unsigned;not null;index"`
	TglPeriksa   *CustomDate `json:"tgl_periksa" gorm:"column:tgl_periksa;type:date"`
	NamaLab      string      `json:"nama_lab" gorm:"column:nama_lab;size:100"`

	// Relationships
	Riwayat  *Riwayat   `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	User     *User      `json:"user,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilLab []HasilLab `json:"hasil_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (LaporanLab) TableName() string {
	return "laporan_lab"
}

// DTO untuk Create Laporan Lab
type CreateLaporanLabRequest struct {
	IDUser     uint        `json:"id_user" binding:"required"`
	IDRiwayat  uint        `json:"id_riwayat,omitempty"`
	TglPeriksa *CustomDate `json:"tgl_periksa"`
	NamaLab    string      `json:"nama_lab" binding:"required"`
}

// DTO untuk Update Laporan Lab
type UpdateLaporanLabRequest struct {
	TglPeriksa *CustomDate `json:"tgl_periksa"`
	NamaLab    string      `json:"nama_lab"`
}
