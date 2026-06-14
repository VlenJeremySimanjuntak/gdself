package models

import "time"

// HasilAIHarian adalah hasil AI yang dihasilkan dari mesin harian (wearable)
type HasilAIHarian struct {
	IDHasilAIHarian uint      `json:"id_hasil_ai_harian" gorm:"column:id_hasil_ai_harian;type:int unsigned;primaryKey;autoIncrement"`
	IDWearable      uint      `json:"id_wearable" gorm:"column:id_wearable;type:int unsigned;not null;index"`
	IDRiwayat       uint      `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	TglHasilAI      time.Time `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai"`
	Score           float64   `json:"score" gorm:"column:score"`
	StatusHarian    string    `json:"status_harian,omitempty" gorm:"column:status_harian;type:varchar(100)"`
	PesanHarian     string    `json:"pesan_harian,omitempty" gorm:"column:pesan_harian;type:text"`
	CreatedAt       time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime"`

	Riwayat  *Riwayat        `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Wearable *WearableRecord `json:"wearable_record,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (HasilAIHarian) TableName() string {
	return "hasil_ai_harian"
}

// HasilAIGabungan adalah hasil AI dari mesin lab/trend (bisa berelasi ke hasil_lab dan/atau wearable)
type HasilAIGabungan struct {
	IDHasilAILab  uint      `json:"id_hasil_ai_lab" gorm:"column:id_hasil_ai_lab;type:int unsigned;primaryKey;autoIncrement"`
	IDHasilLab    *uint     `json:"id_hasil_lab,omitempty" gorm:"column:id_hasil_lab;type:int unsigned;index"`
	IDRiwayat     uint      `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	IDWearable    *uint     `json:"id_wearable,omitempty" gorm:"column:id_wearable;type:int unsigned;index"`
	KesimpulanLab string    `json:"kesimpulan_lab,omitempty" gorm:"column:kesimpulan_lab;type:text"`
	TrendReport   string    `json:"trend_report,omitempty" gorm:"column:trend_report;type:text"`
	ArahPerubahan string    `json:"arah_perubahan,omitempty" gorm:"column:arah_perubahan;type:varchar(100)"`
	TglHasilAI    time.Time `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai"`
	Score         float64   `json:"score" gorm:"column:score"`
	IsRead        bool      `json:"is_read" gorm:"column:is_read"`
	CreatedAt     time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime"`

	HasilLab *HasilLab       `json:"hasil_lab,omitempty" gorm:"foreignKey:IDHasilLab;references:IDHasilLab;constraint:OnUpdate:CASCADE,OnDelete:SET NULL"`
	Riwayat  *Riwayat        `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Wearable *WearableRecord `json:"wearable_record,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:SET NULL"`
}

func (HasilAIGabungan) TableName() string {
	return "hasil_ai_gabungan"
}

// Compatibility struct HasilAI (legacy shape) kept so existing usecases/controllers compile.
type HasilAI struct {
	IDHasilAI     uint       `json:"id_hasil_ai" gorm:"column:id_hasil_ai;type:int unsigned;primaryKey;autoIncrement"`
	IDUser        uint       `json:"id_user" gorm:"column:id_user;type:int unsigned;index"`
	IDRiwayat     *uint      `json:"id_riwayat,omitempty" gorm:"column:id_riwayat;type:int unsigned"`
	IDWearable    *uint      `json:"id_wearable,omitempty" gorm:"column:id_wearable;type:int unsigned"`
	IDHasilLab    *uint      `json:"id_hasil_lab,omitempty" gorm:"column:id_hasil_lab;type:int unsigned"`
	TglHasilAI    time.Time  `json:"tgl_hasil_ai" gorm:"column:tgl_hasil_ai"`
	Score         float64    `json:"score" gorm:"column:score"`
	KesimpulanLab string     `json:"kesimpulan_lab,omitempty" gorm:"column:kesimpulan_lab;type:text"`
	StatusHarian  string     `json:"status_harian,omitempty" gorm:"column:status_harian;type:varchar(100)"`
	PesanHarian   string     `json:"pesan_harian,omitempty" gorm:"column:pesan_harian;type:text"`
	TrendReport   string     `json:"trend_report,omitempty" gorm:"column:trend_report;type:text"`
	ArahPerubahan string     `json:"arah_perubahan,omitempty" gorm:"column:arah_perubahan;type:varchar(100)"`
	FlagUrgensi   string     `json:"flag_urgensi,omitempty" gorm:"column:flag_urgensi;type:varchar(100)"`
	TglKirim      *time.Time `json:"tgl_kirim,omitempty" gorm:"column:tgl_kirim"`
	IsRead        bool       `json:"is_read" gorm:"column:is_read"`
	CreatedAt     time.Time  `json:"created_at" gorm:"column:created_at;autoCreateTime"`

	Riwayat  *Riwayat        `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Wearable *WearableRecord `json:"wearable_record,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilLab *HasilLab       `json:"hasil_lab,omitempty" gorm:"foreignKey:IDHasilLab;references:IDHasilLab;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (HasilAI) TableName() string {
	return "hasil_ai"
}
