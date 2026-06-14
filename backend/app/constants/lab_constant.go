package constants

const (
	FIELD_USER_ID = "user_id"
	FIELD_FT3     = "ft3"
	FIELD_FT4     = "ft4"
	FIELD_TSH     = "tsh"
)

const (
	// NOTES: values adapted to the rule-based AI spec (units must match input)
	FT3_MIN float64 = 2.3
	FT3_MAX float64 = 4.2
	FT4_MIN float64 = 7.6
	FT4_MAX float64 = 15.0
	TSH_MIN float64 = 0.4
	TSH_MAX float64 = 4.0
)

const (
	STATUS_NORMAL = "Normal"
	STATUS_TINGGI = "Tinggi (Hipertiroid)"
	STATUS_RENDAH = "Rendah (Berisiko Graves)"
)
