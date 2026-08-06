package models

import "time"

// ==========================================
// MODEL WEARABLE
// ==========================================
type Wearable struct {
	IDWearable    uint        `json:"id_wearable" gorm:"column:id_wearable;type:int unsigned;primaryKey;autoIncrement"`
	IDRiwayat     uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	TglData       *CustomDate `json:"tgl_data" gorm:"column:tgl_data;type:date"`
	WaktuData     *CustomTime `json:"waktu_data" gorm:"column:waktu_data;type:time"`
	HeartRateHr   int         `json:"heart_rate_hr" gorm:"column:heart_rate_hr"`
	SleepDuration int         `json:"sleep_duration" gorm:"column:sleep_duration"` // dalam menit
	Sistolik      int         `json:"sistolik" gorm:"column:sistolik"`             
	Diastolik     int         `json:"diastolik" gorm:"column:diastolik"`           
	CreatedAt     time.Time   `json:"created_at" gorm:"column:created_at;autoCreateTime:milli"`

	// Relationships
	Riwayat       *Riwayat        `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilAIHarian []HasilAIHarian `json:"hasil_ai_harian,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable"`
}

func (Wearable) TableName() string {
	return "wearable"
}

// ==========================================
// DATA TRANSFER OBJECTS (DTO) WEARABLE
// ==========================================

type CreateWearableRequest struct {
	IDRiwayat     uint        `json:"id_riwayat,omitempty"`
	IDUser        uint        `json:"id_user" binding:"required"`
	TglData       *CustomDate `json:"tgl_data"`
	WaktuData     *CustomTime `json:"waktu_data"`
	HeartRateHr   int         `json:"heart_rate_hr" binding:"required"`
	SleepDuration int         `json:"sleep_duration" binding:"required"`
	Sistolik      int         `json:"sistolik"`  
	Diastolik     int         `json:"diastolik"` 
}

type UpdateWearableRequest struct {
	TglData       *CustomDate `json:"tgl_data"`
	WaktuData     *CustomTime `json:"waktu_data"`
	HeartRateHr   int         `json:"heart_rate_hr"`
	SleepDuration int         `json:"sleep_duration"`
	Sistolik      int         `json:"sistolik"`  
	Diastolik     int         `json:"diastolik"` 
}

// ✅ WearableData dengan HR & Baseline-nya
type WearableData struct {
	HR               float64 `json:"hr"`
	SleepMinutes     float64 `json:"sleep_minutes"`
	Sys              float64 `json:"sys"` 
	Dia              float64 `json:"dia"` 
	BaselineHRMin    float64 `json:"baseline_hr_min"`
	BaselineHRMax    float64 `json:"baseline_hr_max"`
	BaselineSleepMin float64 `json:"baseline_sleep_min"`
	BaselineSleepMax float64 `json:"baseline_sleep_max"`
}