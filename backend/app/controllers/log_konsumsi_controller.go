package controllers

import (
    "net/http"
    "strconv"

    "monitoring-service/app/models"
    "monitoring-service/app/usecases"

    "github.com/labstack/echo/v4"
)

type LogKonsumsiController interface {
    CatatKonsumsi(c echo.Context) error
    GetByJadwalID(c echo.Context) error
    Delete(c echo.Context) error
}

type logKonsumsiController struct {
    usecase usecases.LogKonsumsiUsecase
}

func NewLogKonsumsiController(u usecases.LogKonsumsiUsecase) LogKonsumsiController {
    return &logKonsumsiController{usecase: u}
}

type catatKonsumsiRequest struct {
    IDJadwalObat uint               `json:"id_jadwal_obat"`
    TglKonsumsi  *models.CustomDate `json:"tgl_konsumsi"`
    Status       string             `json:"status"` // Diminum / Terlewat
}

func (ctrl *logKonsumsiController) CatatKonsumsi(c echo.Context) error {
    var input catatKonsumsiRequest
    if err := c.Bind(&input); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
    }

    if input.IDJadwalObat == 0 {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "id_jadwal_obat harus diisi"})
    }
    if input.Status == "" {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "status harus diisi (Diminum/Terlewat)"})
    }

    var tgl models.CustomDate
    if input.TglKonsumsi != nil {
        tgl = *input.TglKonsumsi
    }

    result, err := ctrl.usecase.CatatKonsumsi(input.IDJadwalObat, tgl, input.Status)
    if err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
    }

    return c.JSON(http.StatusCreated, models.Response{
        StatusCode: http.StatusCreated,
        Message:    "Konsumsi obat berhasil dicatat",
        Data:       result,
    })
}

func (ctrl *logKonsumsiController) GetByJadwalID(c echo.Context) error {
    jadwalID, err := strconv.ParseUint(c.Param("jadwal_id"), 10, 32)
    if err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "jadwal_id tidak valid"})
    }

    logs, err := ctrl.usecase.GetByJadwalID(uint(jadwalID))
    if err != nil {
        return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
    }

    if logs == nil {
        logs = []models.LogKonsumsiObat{}
    }

    return c.JSON(http.StatusOK, models.Response{
        StatusCode: http.StatusOK,
        Message:    "Riwayat konsumsi obat",
        Data:       logs,
    })
}

func (ctrl *logKonsumsiController) Delete(c echo.Context) error {
    id, err := strconv.ParseUint(c.Param("id"), 10, 32)
    if err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
    }

    if err := ctrl.usecase.HapusLog(uint(id)); err != nil {
        return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
    }

    return c.JSON(http.StatusOK, models.BasicResponse{
        StatusCode: http.StatusOK,
        Message:    "Log konsumsi berhasil dihapus",
    })
}