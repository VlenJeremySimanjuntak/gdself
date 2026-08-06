package models

import "time"

// ==========================================
// 1. AI HARIAN (Berasal dari Wearable)
// ==========================================
type HasilAIHarian struct {
	IDHasilAIHarian uint        `json:"id_hasil_ai_harian" gorm:"column:id_hasil_ai_harian;type:int unsigned;primaryKey;autoIncrement"`
	IDWearable      uint        `json:"id_wearable" gorm:"column:id_wearable;type:int unsigned;not null;index"`
	StatusHr        string      `json:"status_hr" gorm:"column:status_hr;size:100"`
	ReminderHr      string      `json:"reminder_hr" gorm:"column:reminder_hr;type:text"`
	StatusTidur     string      `json:"status_tidur" gorm:"column:status_tidur;size:100"`
	ReminderTidur   string      `json:"reminder_tidur" gorm:"column:reminder_tidur;type:text"`
	StatusTd        string      `json:"status_td" gorm:"column:status_td;size:100"`       // ✅ Ditambahkan
	ReminderTd      string      `json:"reminder_td" gorm:"column:reminder_td;type:text"` // ✅ Ditambahkan
	TglHasilAi      *CustomDate `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai;type:date"`
	CreatedAt       time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	// Relationships
	Wearable *Wearable `json:"wearable,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (HasilAIHarian) TableName() string {
	return "hasil_ai_harian"
}

// ==========================================
// 2. AI LAB (Berasal dari Laporan Lab)
// ==========================================
type HasilAILab struct {
	IDHasilAILab uint        `json:"id_hasil_ai_lab" gorm:"column:id_hasil_ai_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDLaporanLab uint        `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;not null;index"`
	StatusTsh    string      `json:"status_tsh" gorm:"column:status_tsh;size:100"`
	ReminderTsh  string      `json:"reminder_tsh" gorm:"column:reminder_tsh;type:text"`
	StatusFt3    string      `json:"status_ft3" gorm:"column:status_ft3;size:100"`
	ReminderFt3  string      `json:"reminder_ft3" gorm:"column:reminder_ft3;type:text"`
	StatusFt4    string      `json:"status_ft4" gorm:"column:status_ft4;size:100"`
	ReminderFt4  string      `json:"reminder_ft4" gorm:"column:reminder_ft4;type:text"`
	StatusTrab   string      `json:"status_trab" gorm:"column:status_trab;size:100"`
	ReminderTrab string      `json:"reminder_trab" gorm:"column:reminder_trab;type:text"`
	Interpretasi string      `json:"interpretasi" gorm:"column:interpretasi;type:text"`
	TglHasilAi   *CustomDate `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai;type:date"`
	CreatedAt    time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	// Relationships
	LaporanLab *LaporanLab `json:"laporan_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (HasilAILab) TableName() string {
	return "hasil_ai_lab"
}

// ==========================================
// 3. AI TREN (Berasal dari Laporan Lab)
// ==========================================
type HasilAITren struct {
	IDHasilAITren    uint        `json:"id_hasil_ai_tren" gorm:"column:id_hasil_ai_tren;type:int unsigned;primaryKey;autoIncrement"`
	IDLaporanLab     uint        `json:"id_laporan_lab" gorm:"column:id_laporan_lab;type:int unsigned;not null;index"`
	TrenTsh          string      `json:"tren_tsh" gorm:"column:tren_tsh;size:100"`
	ReminderTrenTsh  string      `json:"reminder_tren_tsh" gorm:"column:reminder_tren_tsh;type:text"`
	TrenFt3          string      `json:"tren_ft3" gorm:"column:tren_ft3;size:100"`
	ReminderTrenFt3  string      `json:"reminder_tren_ft3" gorm:"column:reminder_tren_ft3;type:text"`
	TrenFt4          string      `json:"tren_ft4" gorm:"column:tren_ft4;size:100"`
	ReminderTrenFt4  string      `json:"reminder_tren_ft4" gorm:"column:reminder_tren_ft4;type:text"`
	TrenTrab         string      `json:"tren_trab" gorm:"column:tren_trab;size:100"`
	ReminderTrenTrab string      `json:"reminder_tren_trab" gorm:"column:reminder_tren_trab;type:text"`
	TglHasilAi       *CustomDate `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai;type:date"`
	CreatedAi        time.Time   `json:"created_ai" gorm:"column:created_ai;autoCreateTime:milli"`

	// Relationships
	LaporanLab *LaporanLab `json:"laporan_lab,omitempty" gorm:"foreignKey:IDLaporanLab;references:IDLaporanLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (HasilAITren) TableName() string {
	return "hasil_ai_tren"
}