package models

import "time"

type Obat struct {
	IDObat       uint       `json:"id_obat" gorm:"column:id_obat;type:int unsigned;primaryKey;autoIncrement"`
	IDUser       uint       `json:"id_user" gorm:"column:id_user;type:int unsigned;not null;index"`
	NamaObat     string     `json:"nama_obat" gorm:"column:nama_obat;size:100;not null"`
	Dosis        string     `json:"dosis" gorm:"column:dosis;size:50"`
	Frekuensi    string     `json:"frekuensi" gorm:"column:frekuensi;size:50"`
	TanggalMulai *time.Time `json:"tanggal_mulai" gorm:"column:tanggal_mulai;type:date"`
	HariKonsumsi string     `json:"hari_konsumsi" gorm:"column:hari_konsumsi;type:varchar(100)"`
	StatusAktif  bool       `json:"status_aktif" gorm:"column:status_aktif;default:1"`
	CreatedAt    time.Time  `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`
	UpdatedAt    time.Time  `json:"updated_at" gorm:"column:updated_at;autoUpdateTime:milli"`

	// Relationships
	User       *User        `json:"user,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	JadwalObat []JadwalObat `json:"jadwal_obat,omitempty" gorm:"foreignKey:IDObat;references:IDObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (Obat) TableName() string {
	return "obat"
}

// DTO untuk Create Obat
type CreateObatRequest struct {
	IDUser       uint    `json:"id_user" binding:"required"`
	NamaObat     string  `json:"nama_obat" binding:"required"`
	Dosis        string  `json:"dosis"`
	Frekuensi    string  `json:"frekuensi"`
	TanggalMulai *string `json:"tanggal_mulai"` // YYYY-MM-DD format
	HariKonsumsi string  `json:"hari_konsumsi"` // comma-separated day names
	StatusAktif  *bool   `json:"status_aktif"`
}

// DTO untuk Update Obat
type UpdateObatRequest struct {
	NamaObat     string  `json:"nama_obat"`
	Dosis        string  `json:"dosis"`
	Frekuensi    string  `json:"frekuensi"`
	TanggalMulai *string `json:"tanggal_mulai"` // YYYY-MM-DD format
	HariKonsumsi string  `json:"hari_konsumsi"` // comma-separated day names
	StatusAktif  *bool   `json:"status_aktif"`
}
