package models

import (
	"database/sql/driver"
	"fmt"
	"time"
)

// CustomDate adalah tipe custom untuk handle format YYYY-MM-DD dari JSON
type CustomDate time.Time

const dateFormat = "2006-01-02" // YYYY-MM-DD

// UnmarshalJSON mengubah string JSON YYYY-MM-DD menjadi time.Time
func (cd *CustomDate) UnmarshalJSON(data []byte) error {
	// Buang quote dari JSON string
	dateStr := string(data)
	if len(dateStr) > 2 && dateStr[0] == '"' && dateStr[len(dateStr)-1] == '"' {
		dateStr = dateStr[1 : len(dateStr)-1]
	}

	// Parse dengan format YYYY-MM-DD
	parsedTime, err := time.Parse(dateFormat, dateStr)
	if err != nil {
		return fmt.Errorf("invalid date format. Expected YYYY-MM-DD, got: %s", dateStr)
	}

	*cd = CustomDate(parsedTime)
	return nil
}

// MarshalJSON mengubah CustomDate menjadi string JSON format YYYY-MM-DD
func (cd CustomDate) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`"%s"`, time.Time(cd).Format(dateFormat))), nil
}

// Value untuk GORM - ubah ke time.Time untuk database
func (cd CustomDate) Value() (driver.Value, error) {
	return time.Time(cd), nil
}

// Scan untuk GORM - baca dari database
func (cd *CustomDate) Scan(value interface{}) error {
	if value == nil {
		return nil
	}

	switch v := value.(type) {
	case time.Time:
		*cd = CustomDate(v)
		return nil
	case string:
		parsedTime, err := time.Parse(dateFormat, v)
		if err != nil {
			return err
		}
		*cd = CustomDate(parsedTime)
		return nil
	default:
		return fmt.Errorf("cannot scan %T into CustomDate", value)
	}
}

// String mengembalikan format YYYY-MM-DD
func (cd CustomDate) String() string {
	return time.Time(cd).Format(dateFormat)
}
