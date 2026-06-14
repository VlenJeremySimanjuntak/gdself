package usecases

import (
	"fmt"
	"math"
	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"strings"
)

// Helper function to extract hormone values from Parameters
func extractHormoneValues(params []models.Parameter) (ft3, ft4, tsh float64) {
	for _, p := range params {
		paramName := strings.ToUpper(p.NamaParameter)
		switch paramName {
		case "FT3":
			ft3 = p.Nilai
		case "FT4":
			ft4 = p.Nilai
		case "TSH":
			tsh = p.Nilai
		}
	}
	return ft3, ft4, tsh
}

// computeLabScore returns (score, code)
func computeLabScore(ft3, ft4, tsh float64) (int, string) {
	inFT3 := ft3 >= constants.FT3_MIN && ft3 <= constants.FT3_MAX
	inFT4 := ft4 >= constants.FT4_MIN && ft4 <= constants.FT4_MAX
	inTSH := tsh >= constants.TSH_MIN && tsh <= constants.TSH_MAX

	if inTSH && inFT3 && inFT4 {
		return 1, "1"
	}

	// Graves variants
	if tsh < constants.TSH_MIN && ft3 > constants.FT3_MAX && ft4 > constants.FT4_MAX {
		return 2, "2a"
	}

	if tsh < constants.TSH_MIN && ft3 > constants.FT3_MAX && inFT4 {
		return 2, "2b"
	}

	if tsh < constants.TSH_MIN && inFT3 && ft4 > constants.FT4_MAX {
		return 2, "2c"
	}

	return 3, "3"
}

// computeWearableScore: baseline ranges should be provided. If baseline min/max are zero, treat metric as normal.
func computeWearableScore(w models.WearableData) int {
	abnormal := 0

	// HR
	if !(w.BaselineHRMin == 0 && w.BaselineHRMax == 0) {
		if w.HR < w.BaselineHRMin || w.HR > w.BaselineHRMax {
			abnormal++
		}
	}

	// Stress
	if !(w.BaselineStressMin == 0 && w.BaselineStressMax == 0) {
		if w.Stress < w.BaselineStressMin || w.Stress > w.BaselineStressMax {
			abnormal++
		}
	}

	// Sleep (minutes)
	if !(w.BaselineSleepMin == 0 && w.BaselineSleepMax == 0) {
		if w.SleepMinutes < w.BaselineSleepMin || w.SleepMinutes > w.BaselineSleepMax {
			abnormal++
		}
	}

	switch {
	case abnormal == 0:
		return 1
	case abnormal == 1:
		return 2
	default:
		return 3
	}
}

// computeTrendFactorY: simple rule — if condition worsens, Y=1.1; improves, Y=0.9; else 1.0
func computeTrendFactorY(curr, prev int) float64 {
	if prev == 0 {
		return 1.0
	}
	if curr > prev {
		return 1.1
	}
	if curr < prev {
		return 0.9
	}
	return 1.0
}

func (u *labUsecase) Assess(input models.AssessmentInput) (models.AssessmentResult, error) {
	var res models.AssessmentResult

	// Extract hormone values from Parameters
	ft3, ft4, tsh := extractHormoneValues(input.Lab.Parameters)

	// X
	x, code := computeLabScore(ft3, ft4, tsh)
	res.LabScore = x
	res.LabCode = code

	// Z
	z := computeWearableScore(input.Wearable)
	res.WearableScore = z

	// Y
	y := 1.0
	if input.IsLabDay && input.PrevLab != nil {
		prevFT3, prevFT4, prevTSH := extractHormoneValues(input.PrevLab.Parameters)
		prevX, _ := computeLabScore(prevFT3, prevFT4, prevTSH)

		y = computeTrendFactorY(x, prevX)
	}
	res.TrendFactorY = y

	// Final score
	var final float64
	if input.IsLabDay {
		final = (float64(x)*y)*0.7 + float64(z)*0.3
	} else {
		final = float64(x)*0.7 + float64(z)*0.3
	}

	// Round to one decimal
	res.FinalScore = math.Round(final*10) / 10

	// Interpretation mapping based on the table provided (uses X and Z)
	switch {
	case x == 1 && z == 1:
		res.Interpretation = "Normal / wearable normal"
	case x == 1 && z == 2:
		res.Interpretation = "Normal / wearable sedang"
	case x == 1 && z == 3:
		res.Interpretation = "Normal / wearable jelek"
	case x == 2 && z == 1:
		res.Interpretation = "Graves disease / wearable normal"
	case x == 2 && z == 2:
		res.Interpretation = "Graves disease / wearable sedang"
	case x == 2 && z == 3:
		res.Interpretation = "Graves disease / wearable jelek"
	case x == 3 && z == 1:
		res.Interpretation = "Kondisi tidak diketahui / wearable normal"
	case x == 3 && z == 2:
		res.Interpretation = "Kondisi tidak diketahui / wearable sedang"
	case x == 3 && z == 3:
		res.Interpretation = "Kondisi tidak diketahui / wearable jelek"
	default:
		res.Interpretation = "Perlu evaluasi dokter"
	}

	// Save assessment result to hasil_ai table if usecase is available
	if u.usecaseHasilAI != nil && input.Lab.IDRiwayat != 0 {
		_, err := u.usecaseHasilAI.CreateHasilAI(
			input.Lab.IDRiwayat,
			nil, // wearableID not available in current request structure
			&input.Lab.IDHasilLab,
			res.FinalScore,
		)
		if err != nil {
			// Log error but don't fail the assessment - still return result
			fmt.Printf("Warning: failed to save assessment result: %v\n", err)
		}
	}

	return res, nil
}
