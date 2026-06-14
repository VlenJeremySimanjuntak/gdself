package controllers

import (
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type MonitoringController interface {
	GetByUserID(c echo.Context) error
}

type monitoringController struct {
	laporanUsecase usecases.LaporanLabUsecase
}

func NewMonitoringController(laporan usecases.LaporanLabUsecase) MonitoringController {
	return &monitoringController{laporanUsecase: laporan}
}

func (ctrl *monitoringController) GetByUserID(c echo.Context) error {
	raw := c.Param("user_id")
	uid, err := strconv.ParseUint(raw, 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	laporanList, err := ctrl.laporanUsecase.GetLaporanLabByUserID(uint(uid))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// Group hasil by parameter name (normalized)
	grouped := map[string][]map[string]interface{}{}

	for _, laporan := range laporanList {
		var tgl time.Time
		if laporan.TglPeriksa != nil {
			tgl = time.Time(*laporan.TglPeriksa)
		} else {
			tgl = time.Time{}
		}

		for _, hasil := range laporan.HasilLab {
			if hasil.Parameter == nil {
				continue
			}
			name := strings.ToUpper(strings.TrimSpace(hasil.Parameter.NamaParameter))
			if name == "" {
				continue
			}

			entry := map[string]interface{}{
				"tgl":         tgl.Format("2006-01-02"),
				"month":       strings.ToUpper(tgl.Format("Jan")),
				"date":        tgl.Format("02 Jan 2006"),
				"val":         fmt.Sprintf("%v", hasil.NilaiHasil),
				"value_raw":   hasil.NilaiHasil,
				"unit":        hasil.Parameter.Satuan,
				"rujukan_min": hasil.RujukanMin,
				"rujukan_max": hasil.RujukanMax,
			}

			grouped[name] = append(grouped[name], entry)
		}
	}

	// Build response: for each parameter, sort by date desc and pick up to 2 latest, compute yRatio
	result := map[string][]map[string]interface{}{}

	for name, items := range grouped {
		// sort items by tgl desc
		sortFunc := func(i, j int) bool {
			ti, _ := time.Parse("2006-01-02", items[i]["tgl"].(string))
			tj, _ := time.Parse("2006-01-02", items[j]["tgl"].(string))
			return ti.After(tj)
		}
		// simple bubble-ish sort for small lists
		for i := 0; i < len(items); i++ {
			for j := i + 1; j < len(items); j++ {
				if !sortFunc(i, j) {
					items[i], items[j] = items[j], items[i]
				}
			}
		}

		// determine reference range: prefer first non-zero rujukan from items
		var refMin, refMax float64
		foundRef := false
		var vals []float64
		for _, it := range items {
			vr := it["value_raw"].(float64)
			vals = append(vals, vr)
			rm := it["rujukan_min"].(float64)
			rM := it["rujukan_max"].(float64)
			if !foundRef && rM > rm {
				refMin = rm
				refMax = rM
				foundRef = true
			}
		}

		if !foundRef {
			// fallback to dataset min/max
			if len(vals) > 0 {
				minv := vals[0]
				maxv := vals[0]
				for _, v := range vals {
					if v < minv {
						minv = v
					}
					if v > maxv {
						maxv = v
					}
				}
				if minv == maxv {
					minv = minv - 1.0
					maxv = maxv + 1.0
				}
				refMin = minv
				refMax = maxv
			} else {
				refMin = 0
				refMax = 1
			}
		}

		// take up to 2 latest
		take := 2
		if len(items) < 2 {
			take = len(items)
		}

		out := []map[string]interface{}{}
		for i := 0; i < take; i++ {
			it := items[i]
			raw := it["value_raw"].(float64)
			y := 0.0
			if refMax > refMin {
				y = (raw - refMin) / (refMax - refMin)
			} else {
				y = 0.0
			}
			y = math.Max(0, math.Min(1, y))

			out = append(out, map[string]interface{}{
				"month":  it["month"],
				"date":   it["date"],
				"val":    it["val"],
				"unit":   it["unit"],
				"yRatio": y,
			})
		}

		result[name] = out
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Monitoring aggregated",
		Data:       result,
	})
}
