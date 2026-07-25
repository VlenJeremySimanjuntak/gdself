package models

import "time"

// ==========================================
// 1. MODEL LAPORAN LAB
// ==========================================
type LaporanLab struct {
	IDLaporanLab uint        `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDRiwayat    uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	NamaLab      string      `json:"nama_lab" gorm:"column:nama_lab;size:100"`
	TglPeriksa   *CustomDate `json:"tgl_periksa" gorm:"column:tgl_periksa;type:date"`

	Riwayat     *Riwayat      `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilLab    []HasilLab    `json:"hasil_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab"`
	HasilAILab  []HasilAILab  `json:"hasil_ai_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab"`
	HasilAITren []HasilAITren `json:"hasil_ai_tren,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab"`
}

func (LaporanLab) TableName() string {
	return "laporan_lab"
}

// ==========================================
// 2. MODEL HASIL LAB
// ==========================================
type HasilLab struct {
	IDHasilLab      uint      `json:"id_hasil_lab" gorm:"column:id_hasil_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDLaporanLab    uint      `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;not null;index"`
	IDParameter     uint      `json:"id_parameter" gorm:"column:id_parameter;type:int unsigned;not null;index"`
	
	NilaiHasil      *float64  `json:"nilai_hasil" gorm:"column:nilai_hasil;type:decimal(10,3)"`
	NilaiBatasBawah *float64  `json:"nilai_batas_bawah" gorm:"column:nilai_batas_bawah;type:decimal(10,3)"`
	NilaiBatasAtas  *float64  `json:"nilai_batas_atas" gorm:"column:nilai_batas_atas;type:decimal(10,3)"`
	
	MeasurementStatus     string `json:"measurement_status" gorm:"column:measurement_status;type:varchar(50)"`
	PhysicalConditionCode string `json:"physical_condition_code" gorm:"column:physical_condition_code;type:varchar(100)"`
	PhysicalConditionNote string `json:"physical_condition_note" gorm:"column:physical_condition_note;type:text"`

	CreatedAt       time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	LaporanLab *LaporanLab `json:"laporan_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Parameter  *Parameter  `json:"parameter,omitempty" gorm:"foreignKey:IDParameter;references:IDParameter;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT"`

	IDRiwayat  uint        `json:"id_riwayat,omitempty" gorm:"-"`
	TglPeriksa *CustomDate `json:"tgl_periksa,omitempty" gorm:"-"`
	Parameters []Parameter `json:"parameters,omitempty" gorm:"-"`
}

func (HasilLab) TableName() string {
	return "hasil_lab"
}

// ==========================================
// 3. MODEL USG TIROID (BARU)
// ==========================================
type USGTiroid struct {
	IDUsg          uint        `json:"id_usg" gorm:"column:id_usg;type:int unsigned;primaryKey;autoIncrement"`
	IDRiwayat      uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	NamaRs         string      `json:"nama_rs" gorm:"column:nama_rs;size:100"`
	TglPemeriksaan *CustomDate `json:"tgl_pemeriksaan" gorm:"column:tgl_pemeriksaan;type:date"`
	FotoPath       string      `json:"foto_path" gorm:"column:foto_path;type:varchar(255)"`
	CatatanDokter  string      `json:"catatan_dokter" gorm:"column:catatan_dokter;type:text"`
	CreatedAt      time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	Riwayat *Riwayat `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (USGTiroid) TableName() string {
	return "usg_tiroid"
}

// ==========================================
// DATA TRANSFER OBJECTS (DTO)
// ==========================================

type CreateLaporanLabRequest struct {
	IDUser     uint        `json:"id_user" binding:"required"` // Diperlukan untuk mencari/membuat Riwayat
	IDRiwayat  uint        `json:"id_riwayat,omitempty"`
	TglPeriksa *CustomDate `json:"tgl_periksa"`
	NamaLab    string      `json:"nama_lab" binding:"required"`
}

type UpdateLaporanLabRequest struct {
	TglPeriksa *CustomDate `json:"tgl_periksa"`
	NamaLab    string      `json:"nama_lab"`
}

type CreateHasilLabRequest struct {
	IDLaporanLab    uint                     `json:"id_laporan_lab,omitempty"`
	NilaiHasil      *float64                 `json:"nilai_hasil"`
	NilaiBatasBawah *float64                 `json:"nilai_batas_bawah,omitempty"`
	NilaiBatasAtas  *float64                 `json:"nilai_batas_atas,omitempty"`
	Parameters      []CreateParameterRequest `json:"parameters" binding:"required"`

	ForceSave       bool                     `json:"force_save"`
	IDReport   uint        `json:"id_report,omitempty"`
	IDRiwayat  uint        `json:"id_riwayat,omitempty"`
	IDUser     uint        `json:"id_user,omitempty"`
	NamaLab    string      `json:"nama_lab,omitempty"`
	TglPeriksa *CustomDate `json:"tgl_periksa,omitempty"`
}

// DTO untuk Update Hasil Lab
type UpdateHasilLabRequest struct {
	NilaiHasil            *float64 `json:"nilai_hasil"`
	NilaiBatasBawah       *float64 `json:"nilai_batas_bawah"`
	NilaiBatasAtas        *float64 `json:"nilai_batas_atas"`
	MeasurementStatus     string   `json:"measurement_status,omitempty"`
	PhysicalConditionCode string   `json:"physical_condition_code,omitempty"`
	PhysicalConditionNote string   `json:"physical_condition_note,omitempty"`
	ForceSave             bool     `json:"force_save"`
}