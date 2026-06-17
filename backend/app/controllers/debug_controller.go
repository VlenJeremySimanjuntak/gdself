package controllers

import (
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
)

type DebugController struct{}

func NewDebugController() *DebugController {
	return &DebugController{}
}

// Ping test basic response
func (d *DebugController) Ping(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "ok",
		"time":   time.Now().Format("2006-01-02 15:04:05"),
	})
}

// TestJSON test JSON serialization
func (d *DebugController) TestJSON(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": "JSON response working",
		"data": map[string]interface{}{
			"id":    1,
			"name":  "Test",
			"email": "test@test.com",
			"date":  time.Now().Format("2006-01-02"),
		},
	})
}