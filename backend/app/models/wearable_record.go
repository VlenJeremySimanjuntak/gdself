package models

type WearableRecord struct {
	IDWearable    uint        `json:"id_wearable" gorm:"column:id_wearable;type:int unsigned;primaryKey;autoIncrement"`
	IDRiwayat     uint        `json:"id_riwayat" gorm:"column:id_riwayat;type:int unsigned;not null;index"`
	TglData       *CustomDate `json:"tgl_data" gorm:"column:tgl_data;type:date"`
	WaktuData     *CustomTime `json:"waktu_data" gorm:"column:waktu_data;type:time"`
	HeartRateRHR  int         `json:"heart_rate_rhr" gorm:"column:heart_rate_rhr"`
	StressScore   int         `json:"stress_score" gorm:"column:stress_score"`
	SleepDuration int         `json:"sleep_duration" gorm:"column:sleep_duration"` // dalam menit

	// Relationships
	Riwayat         *Riwayat          `json:"riwayat,omitempty" gorm:"foreignKey:IDRiwayat;references:IDRiwayat;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilAIHarian   []HasilAIHarian   `json:"hasil_ai_harian,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	HasilAIGabungan []HasilAIGabungan `json:"hasil_ai_gabungan,omitempty" gorm:"foreignKey:IDWearable;references:IDWearable;constraint:OnUpdate:CASCADE,OnDelete:SET NULL"`
}

func (WearableRecord) TableName() string {
	return "wearable"
}

// DTO untuk Create Wearable
type CreateWearableRequest struct {
	IDRiwayat     uint        `json:"id_riwayat,omitempty"`
	IDUser        uint        `json:"id_user" binding:"required"`
	TglData       *CustomDate `json:"tgl_data"`
	WaktuData     *CustomTime `json:"waktu_data"`
	HeartRateRHR  int         `json:"heart_rate_rhr" binding:"required"`
	StressScore   int         `json:"stress_score" binding:"required"`
	SleepDuration int         `json:"sleep_duration" binding:"required"`
}

// DTO untuk Update Wearable
type UpdateWearableRequest struct {
	TglData       *CustomDate `json:"tgl_data"`
	WaktuData     *CustomTime `json:"waktu_data"`
	HeartRateRHR  int         `json:"heart_rate_rhr"`
	StressScore   int         `json:"stress_score"`
	SleepDuration int         `json:"sleep_duration"`
}
