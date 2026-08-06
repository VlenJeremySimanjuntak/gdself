package models

import (
	"database/sql/driver"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

type CustomTime time.Time

const timeFormat = "15:04:05"
const shortTimeFormat = "15:04"

// ✅ KODE BARU: Gunakan WIB sejak awal, bukan UTC
func normalizeCustomTime(hour, minute, second int) time.Time {
	wib := time.FixedZone("WIB", 7*3600)
	return time.Date(2000, time.January, 1, hour, minute, second, 0, wib)
}

func (CustomTime) GormDataType() string {
	return "time"
}

func (CustomTime) GormDBDataType(db *gorm.DB, field *schema.Field) string {
	return "TIME"
}

func (ct *CustomTime) UnmarshalJSON(data []byte) error {
	s := string(data)
	if len(s) > 2 && s[0] == '"' && s[len(s)-1] == '"' {
		s = s[1 : len(s)-1]
	}
	if s == "" || s == "null" {
		return nil
	}

	wib := time.FixedZone("WIB", 7*3600)

	// Coba parsing format 15:04:05
	t, err := time.ParseInLocation(timeFormat, s, wib)
	if err == nil {
		*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second()))
		return nil
	}

	// Coba parsing format 15:04 (sering dikirim dari mobile)
	t2, err2 := time.ParseInLocation(shortTimeFormat, s, wib)
	if err2 == nil {
		*ct = CustomTime(normalizeCustomTime(t2.Hour(), t2.Minute(), 0))
		return nil
	}

	// Coba RFC3339
	t3, err3 := time.ParseInLocation(time.RFC3339, s, wib)
	if err3 == nil {
		*ct = CustomTime(normalizeCustomTime(t3.Hour(), t3.Minute(), t3.Second()))
		return nil
	}

	return fmt.Errorf("invalid time format: %s", s)
}

func (ct CustomTime) MarshalJSON() ([]byte, error) {
	wib := time.FixedZone("WIB", 7*3600)
	return []byte(fmt.Sprintf("\"%s\"", time.Time(ct).In(wib).Format(timeFormat))), nil
}

func (ct CustomTime) Value() (driver.Value, error) {
	wib := time.FixedZone("WIB", 7*3600)
	return time.Time(ct).In(wib).Format(timeFormat), nil
}

func (ct *CustomTime) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	wib := time.FixedZone("WIB", 7*3600)

	switch v := value.(type) {
	case time.Time:
		*ct = CustomTime(v.In(wib))
		return nil
	case []byte:
		s := string(v)
		t, err := time.ParseInLocation(timeFormat, s, wib)
		if err == nil {
			*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second()))
			return nil
		}
		return fmt.Errorf("cannot scan []byte to CustomTime: %s", s)
	case string:
		t, err := time.ParseInLocation(timeFormat, v, wib)
		if err == nil {
			*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second()))
			return nil
		}
		return fmt.Errorf("cannot scan string to CustomTime: %s", v)
	default:
		return fmt.Errorf("cannot scan %T into CustomTime", value)
	}
}

func (ct CustomTime) String() string {
	wib := time.FixedZone("WIB", 7*3600)
	return time.Time(ct).In(wib).Format(timeFormat)
}