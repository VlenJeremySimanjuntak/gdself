package models

type AssessmentInput struct {
	Lab      AssessmentLabInput   `json:"lab"`
	PrevLab  *AssessmentLabInput  `json:"prev_lab,omitempty"`
	Wearable *WearableData        `json:"wearable,omitempty"` // Dibuat pointer agar opsional & aman
	IsLabDay bool                 `json:"is_lab_day"`
}

type AssessmentLabInput struct {
	IDLaporanLab uint                   `json:"id_laporan_lab"`
	Parameters   []AssessmentParamInput `json:"parameters"`
}

type AssessmentParamInput struct {
	NamaParameter   string  `json:"nama_parameter"`
	NilaiHasil      float64 `json:"nilai_hasil"`
	NilaiBatasBawah float64 `json:"nilai_batas_bawah"`
	NilaiBatasAtas  float64 `json:"nilai_batas_atas"`
}

type AssessmentResult struct {
	Interpretation string `json:"interpretation"`
}

type RangeNilai struct {
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}