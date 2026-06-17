package models

type AssessmentInput struct {
	Lab      AssessmentLabInput `json:"lab"`
	PrevLab  *AssessmentLabInput `json:"prev_lab,omitempty"`
	Wearable WearableData        `json:"wearable"`
	IsLabDay bool                `json:"is_lab_day"`
}

type AssessmentLabInput struct {
	IDLaporanLab uint                     `json:"id_laporan_lab"`
	Parameters   []AssessmentParamInput   `json:"parameters"`
}

type AssessmentParamInput struct {
	NamaParameter   string  `json:"nama_parameter"`
	NilaiHasil      float64 `json:"nilai_hasil"`
	NilaiBatasBawah float64 `json:"nilai_batas_bawah"`
	NilaiBatasAtas  float64 `json:"nilai_batas_atas"`
}

type AssessmentResult struct {
	LabScore       int     `json:"lab_score"`
	LabCode        string  `json:"lab_code"`
	WearableScore  int     `json:"wearable_score"`
	TrendFactorY   float64 `json:"trend_factor_y"`
	FinalScore     float64 `json:"final_score"`
	Interpretation string  `json:"interpretation"`
}

// RangeNilai untuk menyimpan nilai min dan max dari input user
type RangeNilai struct {
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}