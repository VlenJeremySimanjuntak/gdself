package models

import (
	"database/sql/driver"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

// CustomTime handles time-only values like "15:04:05"
type CustomTime time.Time

const timeFormat = "15:04:05"

func normalizeCustomTime(hour, minute, second int, loc *time.Location) time.Time {
	if loc == nil {
		loc = time.Local
	}

	return time.Date(2000, time.January, 1, hour, minute, second, 0, loc)
}

// GormDataType ensures GORM treats this field as time-only.
func (CustomTime) GormDataType() string {
	return "time"
}

// GormDBDataType ensures MySQL migrations use TIME instead of DATETIME.
func (CustomTime) GormDBDataType(db *gorm.DB, field *schema.Field) string {
	return "TIME"
}

// UnmarshalJSON parses a JSON string in HH:MM:SS format
func (ct *CustomTime) UnmarshalJSON(data []byte) error {
	s := string(data)
	if len(s) > 2 && s[0] == '"' && s[len(s)-1] == '"' {
		s = s[1 : len(s)-1]
	}
	if s == "" || s == "null" {
		return nil
	}

	// try time-only format
	t, err := time.Parse(timeFormat, s)
	if err == nil {
		*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second(), t.Location()))
		return nil
	}

	// fallback: try full RFC3339
	t2, err2 := time.Parse(time.RFC3339, s)
	if err2 == nil {
		*ct = CustomTime(normalizeCustomTime(t2.Hour(), t2.Minute(), t2.Second(), t2.Location()))
		return nil
	}

	return fmt.Errorf("invalid time format: %s", s)
}

// MarshalJSON writes time in HH:MM:SS
func (ct CustomTime) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf("\"%s\"", time.Time(ct).Format(timeFormat))), nil
}

// Value returns a driver.Value for database storage
func (ct CustomTime) Value() (driver.Value, error) {
	return time.Time(ct).Format(timeFormat), nil
}

// Scan reads from database value
func (ct *CustomTime) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	switch v := value.(type) {
	case time.Time:
		*ct = CustomTime(normalizeCustomTime(v.Hour(), v.Minute(), v.Second(), v.Location()))
		return nil
	case []byte:
		s := string(v)
		t, err := time.Parse(timeFormat, s)
		if err == nil {
			*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second(), t.Location()))
			return nil
		}
		t2, err2 := time.Parse(time.RFC3339, s)
		if err2 == nil {
			*ct = CustomTime(normalizeCustomTime(t2.Hour(), t2.Minute(), t2.Second(), t2.Location()))
			return nil
		}
		return fmt.Errorf("cannot scan []byte to CustomTime: %s", s)
	case string:
		t, err := time.Parse(timeFormat, v)
		if err == nil {
			*ct = CustomTime(normalizeCustomTime(t.Hour(), t.Minute(), t.Second(), t.Location()))
			return nil
		}
		t2, err2 := time.Parse(time.RFC3339, v)
		if err2 == nil {
			*ct = CustomTime(normalizeCustomTime(t2.Hour(), t2.Minute(), t2.Second(), t2.Location()))
			return nil
		}
		return fmt.Errorf("cannot scan string to CustomTime: %s", v)
	default:
		return fmt.Errorf("cannot scan %T into CustomTime", value)
	}
}

// String returns HH:MM:SS
func (ct CustomTime) String() string {
	return time.Time(ct).Format(timeFormat)
}
