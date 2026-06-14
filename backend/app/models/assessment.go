package models

type AssessmentInput struct {
	// Latest lab values (required when is_lab_day=true)
	Lab HasilLab `json:"lab"`
	// Previous lab (optional) — used to compute trend factor Y
	PrevLab *HasilLab `json:"prev_lab,omitempty"`
	// Wearable metrics to compute Z
	Wearable WearableData `json:"wearable"`
	// Whether this assessment is done on lab day
	IsLabDay bool `json:"is_lab_day"`
}

type AssessmentResult struct {
	LabScore       int     `json:"lab_score"`
	LabCode        string  `json:"lab_code"`
	WearableScore  int     `json:"wearable_score"`
	TrendFactorY   float64 `json:"trend_factor_y"`
	FinalScore     float64 `json:"final_score"`
	Interpretation string  `json:"interpretation"`
}
