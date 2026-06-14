package models

import "time"

type JadwalObat struct {
	IDJadwalObat   uint        `json:"id_jadwal_obat" gorm:"column:id_jadwal_obat;type:int unsigned;primaryKey;autoIncrement"`
	IDObat         uint        `json:"id_obat" gorm:"column:id_obat;type:int unsigned;not null;index"`
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat" gorm:"column:waktu_minum_obat;type:time"`
	CreatedAt      time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`
	UpdatedAt      time.Time   `json:"updated_at" gorm:"column:updated_at;autoUpdateTime:milli"`

	// Relationships
	Obat *Obat `json:"obat,omitempty" gorm:"foreignKey:IDObat;references:IDObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (JadwalObat) TableName() string {
	return "jadwal_obat"
}

// DTO untuk Create Jadwal Obat
type CreateJadwalObatRequest struct {
	IDObat         uint        `json:"id_obat" binding:"required"`
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat"`
}

// DTO untuk Update Jadwal Obat
type UpdateJadwalObatRequest struct {
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat"`
}
