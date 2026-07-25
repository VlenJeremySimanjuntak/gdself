package models

import (
	"database/sql/driver"
	"fmt"
	"time"
)

type CustomDate time.Time

const dateFormat = "2006-01-02"

func (cd *CustomDate) UnmarshalJSON(data []byte) error {
	dateStr := string(data)
	if len(dateStr) > 2 && dateStr[0] == '"' && dateStr[len(dateStr)-1] == '"' {
		dateStr = dateStr[1 : len(dateStr)-1]
	}
	wib := time.FixedZone("WIB", 7*3600)
	parsedTime, err := time.ParseInLocation(dateFormat, dateStr, wib)
	if err != nil {
		return fmt.Errorf("invalid date format. Expected YYYY-MM-DD, got: %s", dateStr)
	}
	*cd = CustomDate(parsedTime)
	return nil
}

func (cd CustomDate) MarshalJSON() ([]byte, error) {
	wib := time.FixedZone("WIB", 7*3600)
	return []byte(fmt.Sprintf(`"%s"`, time.Time(cd).In(wib).Format(dateFormat))), nil
}

// Value dengan perbaikan Timezone WIB
func (cd CustomDate) Value() (driver.Value, error) {
	wib := time.FixedZone("WIB", 7*3600)
	return time.Time(cd).In(wib).Format(dateFormat), nil
}

// Scan dengan perbaikan Timezone WIB
func (cd *CustomDate) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	wib := time.FixedZone("WIB", 7*3600)

	switch v := value.(type) {
	case time.Time:
		*cd = CustomDate(v.In(wib))
		return nil
	case string:
		parsedTime, err := time.ParseInLocation(dateFormat, v, wib)
		if err != nil {
			return err
		}
		*cd = CustomDate(parsedTime)
		return nil
	case []byte:
		parsedTime, err := time.ParseInLocation(dateFormat, string(v), wib)
		if err != nil {
			return err
		}
		*cd = CustomDate(parsedTime)
		return nil
	default:
		return fmt.Errorf("cannot scan %T into CustomDate", value)
	}
}

func (cd CustomDate) String() string {
	wib := time.FixedZone("WIB", 7*3600)
	return time.Time(cd).In(wib).Format(dateFormat)
}