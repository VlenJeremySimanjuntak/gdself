package models

type WearableData struct {
	HR           float64 `json:"hr"`
	Stress       float64 `json:"stress"`
	SleepMinutes float64 `json:"sleep_minutes"`

	// Baseline ranges (from first 3 days). If zero, caller may treat as unknown.
	BaselineHRMin     float64 `json:"baseline_hr_min"`
	BaselineHRMax     float64 `json:"baseline_hr_max"`
	BaselineStressMin float64 `json:"baseline_stress_min"`
	BaselineStressMax float64 `json:"baseline_stress_max"`
	BaselineSleepMin  float64 `json:"baseline_sleep_min"`
	BaselineSleepMax  float64 `json:"baseline_sleep_max"`
}
