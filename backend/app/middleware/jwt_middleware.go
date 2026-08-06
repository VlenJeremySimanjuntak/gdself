package middleware

import (
	"net/http"
	"strings"

	"monitoring-service/app/helpers"

	"github.com/labstack/echo/v4"
)

func JWTMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
				return c.JSON(http.StatusUnauthorized, map[string]string{
					"error": "token tidak ditemukan",
				})
			}

			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			claims, err := helpers.ParseToken(tokenStr)
			if err != nil {
				return c.JSON(http.StatusUnauthorized, map[string]string{
					"error": "token tidak valid atau sudah kedaluwarsa",
				})
			}

			// Simpan claims ke context supaya bisa dipakai controller
			c.Set("user_id", claims.UserID)
			c.Set("email", claims.Email)

			return next(c)
		}
	}
}