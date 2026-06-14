package models

type Riwayat struct {
	IDRiwayat uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;primaryKey;autoIncrement"`
	IDUser    uint        `json:"id_user" gorm:"column:id_user;type:int unsigned;not null;index"`
	Tanggal   *CustomDate `json:"tanggal" gorm:"column:tanggal;type:date"`

	// Relationships
	User            *User             `json:"user,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Wearable        []WearableRecord  `json:"wearable,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	LaporanLab      []LaporanLab      `json:"laporan_lab,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilAIHarian   []HasilAIHarian   `json:"hasil_ai_harian,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilAIGabungan []HasilAIGabungan `json:"hasil_ai_gabungan,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (Riwayat) TableName() string {
	return "riwayat"
}

// DTO untuk Create Riwayat
type CreateRiwayatRequest struct {
	IDUser  uint        `json:"id_user" binding:"required"`
	Tanggal *CustomDate `json:"tanggal"`
}

// DTO untuk Update Riwayat
type UpdateRiwayatRequest struct {
	Tanggal *CustomDate `json:"tanggal"`
}
