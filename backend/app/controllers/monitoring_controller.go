package controllers

import (
	"fmt"
	"math"
	"net/http"
	"sort"
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
	labUsecase     usecases.LabUsecase
}

func NewMonitoringController(
	laporan usecases.LaporanLabUsecase,
	lab usecases.LabUsecase,
) MonitoringController {
	return &monitoringController{
		laporanUsecase: laporan,
		labUsecase:     lab,
	}
}

func (ctrl *monitoringController) GetByUserID(c echo.Context) error {
	raw := c.Param("user_id")
	uid, err := strconv.ParseUint(raw, 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "user_id tidak valid",
		})
	}

	// Gunakan LabUsecase.GetLabResultsByUserID untuk mendapatkan hasil lab langsung
	hasilLabList, err := ctrl.labUsecase.GetLabResultsByUserID(uint(uid))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Group hasil by parameter name (normalized)
	grouped := map[string][]map[string]interface{}{}

	for _, hasil := range hasilLabList {
		// Skip jika Parameter tidak ada
		if hasil.Parameter == nil {
			continue
		}

		// Normalisasi nama parameter
		name := strings.ToUpper(strings.TrimSpace(hasil.Parameter.NamaParameter))
		if name == "" {
			continue
		}

		// Tentukan tanggal dari LaporanLab terkait
		var tgl time.Time
		if hasil.LaporanLab != nil && hasil.LaporanLab.TglPeriksa != nil {
			tgl = time.Time(*hasil.LaporanLab.TglPeriksa)
		} else if hasil.TglPeriksa != nil {
			// Fallback ke TglPeriksa dari HasilLab (backward compatibility)
			tgl = time.Time(*hasil.TglPeriksa)
		} else {
			// Fallback terakhir ke CreatedAt
			tgl = hasil.CreatedAt
		}

		entry := map[string]interface{}{
			"tgl":         tgl.Format("2006-01-02"),
			"month":       strings.ToUpper(tgl.Format("Jan")),
			"date":        tgl.Format("02 Jan 2006"),
			"val":         fmt.Sprintf("%.2f", hasil.NilaiHasil),
			"value_raw":   hasil.NilaiHasil,
			"unit":        hasil.Parameter.Satuan,
			"rujukan_min": hasil.NilaiBatasBawah,
			"rujukan_max": hasil.NilaiBatasAtas,
		}

		grouped[name] = append(grouped[name], entry)
	}

	// Build response: for each parameter, sort by date desc, pick up to 2 latest, compute yRatio
	result := map[string][]map[string]interface{}{}

	for name, items := range grouped {
		// Sort items by date descending (menggunakan sort.Slice yang lebih idiomatic)
		sort.Slice(items, func(i, j int) bool {
			ti, _ := time.Parse("2006-01-02", items[i]["tgl"].(string))
			tj, _ := time.Parse("2006-01-02", items[j]["tgl"].(string))
			return ti.After(tj)
		})

		// Determine reference range: prefer first non-zero rujukan from items
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

		// Fallback jika tidak ada reference range yang valid
		if !foundRef {
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

		// Take up to 2 latest entries
		take := 2
		if len(items) < 2 {
			take = len(items)
		}

		out := []map[string]interface{}{}
		for i := 0; i < take; i++ {
			it := items[i]
			raw := it["value_raw"].(float64)

			// Calculate yRatio (0-1 scale)
			y := 0.0
			if refMax > refMin {
				y = (raw - refMin) / (refMax - refMin)
			}
			y = math.Max(0, math.Min(1, y))

			out = append(out, map[string]interface{}{
				"month":  it["month"],
				"date":   it["date"],
				"val":    it["val"],
				"unit":   it["unit"],
				"yRatio": math.Round(y*100) / 100, // Round to 2 decimal places
			})
		}

		result[name] = out
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Monitoring data berhasil diambil",
		Data:       result,
	})
}