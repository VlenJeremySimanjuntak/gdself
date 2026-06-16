package models

import "time"

// ==========================================
// 1. MODEL TABEL OBAT
// ==========================================
type Obat struct {
	IDObat     uint        `json:"id_obat" gorm:"column:id_obat;type:int unsigned;primaryKey;autoIncrement"`
	IDUser     uint        `json:"id_user" gorm:"column:id_user;type:int unsigned;not null;index"`
	NamaObat   string      `json:"nama_obat" gorm:"column:nama_obat;size:100;not null"`
	TglMulai   *CustomDate `json:"tgl_mulai" gorm:"column:tgl_mulai;type:date"`
	TglSelesai *CustomDate `json:"tgl_selesai" gorm:"column:tgl_selesai;type:date"`
	TipeObat   string      `json:"tipe_obat" gorm:"column:tipe_obat;size:50"`
	Dosis      string      `json:"dosis" gorm:"column:dosis;size:50"`
	Frekuensi  string      `json:"frekuensi" gorm:"column:frekuensi;size:50"`
	CreatedAt  time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`
	UpdatedAt  time.Time   `json:"updated_at" gorm:"column:updated_at;autoUpdateTime:milli"`

	// Relationships
	User       *User        `json:"user,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	JadwalObat []JadwalObat `json:"jadwal_obat,omitempty" gorm:"foreignKey:IDObat;references:IDObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (Obat) TableName() string {
	return "obat"
}

// ==========================================
// 2. MODEL TABEL JADWAL OBAT
// ==========================================
type JadwalObat struct {
	IDJadwalObat   uint        `json:"id_jadwal_obat" gorm:"column:id_jadwal_obat;type:int unsigned;primaryKey;autoIncrement"`
	IDObat         uint        `json:"id_obat" gorm:"column:id_obat;type:int unsigned;not null;index"`
	Hari           string      `json:"hari" gorm:"column:hari;size:50"`
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat" gorm:"column:waktu_minum_obat;type:time"`
	CreatedAt      time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`
	UpdatedAt      time.Time   `json:"updated_at" gorm:"column:updated_at;autoUpdateTime:milli"`

	// Relationships
	Obat        *Obat             `json:"obat,omitempty" gorm:"foreignKey:IDObat;references:IDObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	LogKonsumsi []LogKonsumsiObat `json:"log_konsumsi,omitempty" gorm:"foreignKey:IDJadwalObat;references:IDJadwalObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (JadwalObat) TableName() string {
	return "jadwal_obat"
}

// ==========================================
// 3. MODEL TABEL LOG KONSUMSI OBAT (BARU)
// ==========================================
type LogKonsumsiObat struct {
	IDLog        uint        `json:"id_log" gorm:"column:id_log;type:int unsigned;primaryKey;autoIncrement"`
	IDJadwalObat uint        `json:"id_jadwal_obat" gorm:"column:id_jadwal_obat;type:int unsigned;not null;index"`
	TglKonsumsi  *CustomDate `json:"tgl_konsumsi" gorm:"column:tgl_konsumsi;type:date"`
	Status       string      `json:"status" gorm:"column:status;size:50"`

	// Relationships
	JadwalObat *JadwalObat `json:"jadwal_obat,omitempty" gorm:"foreignKey:IDJadwalObat;references:IDJadwalObat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (LogKonsumsiObat) TableName() string {
	return "log_konsumsi_obat"
}

// ==========================================
// 4. DATA TRANSFER OBJECTS (DTO)
// ==========================================

// DTO untuk Create Obat
type CreateObatRequest struct {
	IDUser     uint        `json:"id_user" binding:"required"`
	NamaObat   string      `json:"nama_obat" binding:"required"`
	TglMulai   *CustomDate `json:"tgl_mulai"`
	TglSelesai *CustomDate `json:"tgl_selesai"`
	TipeObat   string      `json:"tipe_obat"`
	Dosis      string      `json:"dosis"`
	Frekuensi  string      `json:"frekuensi"`
}

// DTO untuk Update Obat
type UpdateObatRequest struct {
	NamaObat   string      `json:"nama_obat"`
	TglMulai   *CustomDate `json:"tgl_mulai"`
	TglSelesai *CustomDate `json:"tgl_selesai"`
	TipeObat   string      `json:"tipe_obat"`
	Dosis      string      `json:"dosis"`
	Frekuensi  string      `json:"frekuensi"`
}

// DTO untuk Create Jadwal Obat
type CreateJadwalObatRequest struct {
	IDObat         uint        `json:"id_obat" binding:"required"`
	Hari           string      `json:"hari" binding:"required"`
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat" binding:"required"`
}

// DTO untuk Update Jadwal Obat
type UpdateJadwalObatRequest struct {
	Hari           string      `json:"hari"`
	WaktuMinumObat *CustomTime `json:"waktu_minum_obat"`
}