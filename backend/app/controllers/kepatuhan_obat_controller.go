package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type KepatuhanObatController interface {
	GetByObatID(c echo.Context) error
}

type kepatuhanObatController struct {
	usecase usecases.KepatuhanObatUsecase
}

func NewKepatuhanObatController(u usecases.KepatuhanObatUsecase) KepatuhanObatController {
	return &kepatuhanObatController{usecase: u}
}

func (ctrl *kepatuhanObatController) GetByObatID(c echo.Context) error {
	obatID, err := strconv.ParseUint(c.Param("obat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "obat_id tidak valid"})
	}

	result, err := ctrl.usecase.GetKepatuhanObat(uint(obatID))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data kepatuhan obat ditemukan",
		Data:       result,
	})
}
