package routes

import (
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"monitoring-service/app/controllers"
	"time"
)

func ConfigureRouter(e *echo.Echo, controller *controllers.Main) {
	e.Use(middleware.TimeoutWithConfig(middleware.TimeoutConfig{
		Timeout: 30 * time.Second,
	}))

	debugCtrl := controllers.NewDebugController()
	e.GET("/ping", debugCtrl.Ping)
	e.GET("/test-json", debugCtrl.TestJSON)
	e.Static("/uploads", "uploads")

	api := e.Group("/api")

	api.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Content-Type", "Authorization"},
		MaxAge:       86400,
	}))

	api.Use(middleware.RateLimiter(middleware.NewRateLimiterMemoryStore(20)))

	// ========================
	// User Endpoints
	// ========================
	api.POST("/auth/login", controller.User.Login)    // ✅ fix: Luseogin → Login
	api.POST("/auth/register", controller.User.Create)
	api.POST("/auth/google", controller.User.GoogleLogin)

	api.POST("/users/:id/avatar", controller.User.UploadAvatar)
	api.POST("/login", controller.User.Login)
	api.POST("/users", controller.User.Create)
	api.GET("/users", controller.User.GetAll)
	api.GET("/users/:id", controller.User.GetByID)
	api.PUT("/users/:id", controller.User.Update)
	api.DELETE("/users/:id", controller.User.Delete)

	// ========================
	// Riwayat Endpoints
	// ========================
	api.POST("/riwayat", controller.Riwayat.Create)
	api.GET("/riwayat", controller.Riwayat.GetAll)
	api.GET("/riwayat/user/:user_id", controller.Riwayat.GetByUserID)
	api.GET("/riwayat/:id", controller.Riwayat.GetByID)
	api.PUT("/riwayat/:id", controller.Riwayat.Update)
	api.DELETE("/riwayat/:id", controller.Riwayat.Delete)

	// ========================
	// Laporan Lab Endpoints
	// ========================
	api.POST("/laporan-lab", controller.LaporanLab.Create)
	api.GET("/laporan-lab", controller.LaporanLab.GetAll)
	api.GET("/laporan-lab/user/:user_id", controller.LaporanLab.GetByUserID)
	api.GET("/laporan-lab/:id", controller.LaporanLab.GetByID)
	api.PUT("/laporan-lab/:id", controller.LaporanLab.Update)
	api.DELETE("/laporan-lab/:id", controller.LaporanLab.Delete)

	// ========================
	// Monitoring Endpoint (Aggregated)
	// ========================
	api.GET("/monitoring/user/:user_id", controller.Monitoring.GetByUserID)

	// ========================
	// Obat Endpoints
	// ========================
	api.POST("/obat", controller.Obat.Create)
	api.GET("/obat", controller.Obat.GetAll)
	api.GET("/obat/user/:user_id", controller.Obat.GetByUserID)
	api.GET("/obat/:id", controller.Obat.GetByID)
	api.PUT("/obat/:id", controller.Obat.Update)
	api.DELETE("/obat/:id", controller.Obat.Delete)

	// ========================
	// Rekapan Obat
	// ========================
	api.POST("/log-konsumsi", controller.LogKonsumsi.CatatKonsumsi)
	api.GET("/log-konsumsi/jadwal/:jadwal_id", controller.LogKonsumsi.GetByJadwalID)

	// ========================
	// Wearable Endpoints
	// ========================
	api.POST("/wearable", controller.Wearable.Create)
	api.GET("/wearable", controller.Wearable.GetAll)
	api.GET("/wearable/riwayat/:riwayat_id", controller.Wearable.GetByRiwayatID)
	api.GET("/wearable/user/:user_id", controller.Wearable.GetByUserID)
	api.GET("/wearable/:id", controller.Wearable.GetByID)
	api.PUT("/wearable/:id", controller.Wearable.Update)
	api.DELETE("/wearable/:id", controller.Wearable.Delete)

	// ========================
	// Hasil Lab Endpoints
	// ========================
	api.POST("/hasil-lab", controller.HasilLab.Create)
	api.GET("/hasil-lab", controller.HasilLab.GetAll)
	api.GET("/hasil-lab/laporan/:laporan_id", controller.HasilLab.GetByLaporanLabID)
	api.GET("/hasil-lab/riwayat/:riwayat_id", controller.HasilLab.GetByRiwayatID)
	api.GET("/hasil-lab/user/:id_user/date/:tanggal", controller.HasilLab.GetByUserAndDate)
	api.GET("/hasil-lab/riwayat/:riwayat_id/date/:date", controller.HasilLab.GetByRiwayatAndDate)
	api.GET("/hasil-lab/:id", controller.HasilLab.GetByID)
	api.PUT("/hasil-lab/:id", controller.HasilLab.Update)
	api.DELETE("/hasil-lab/:id", controller.HasilLab.Delete)

	// ========================
	// Hasil AI Endpoints
	// ========================

	// Hasil AI Harian (dari Wearable)
	api.POST("/hasil-ai/harian", controller.HasilAI.CreateHarian)
	api.GET("/hasil-ai/harian/wearable/:wearable_id", controller.HasilAI.GetHarianByWearableID)
	api.GET("/hasil-ai/harian/riwayat/:riwayat_id", controller.HasilAI.GetHarianByRiwayatID)
	api.GET("/hasil-ai/harian/:id", controller.HasilAI.GetHarianByID)

	// Hasil AI Lab (dari Laporan Lab)
	api.GET("/hasil-ai/lab/laporan/:laporan_lab_id", controller.HasilAI.GetLabByLaporanLabID)
	api.GET("/hasil-ai/lab/:id", controller.HasilAI.GetLabByID)

	// Hasil AI Tren (dari Laporan Lab)
	api.GET("/hasil-ai/tren/laporan/:laporan_lab_id", controller.HasilAI.GetTrenByLaporanLabID)
	api.GET("/hasil-ai/tren/:id", controller.HasilAI.GetTrenByID)

	// Process Assessment
	api.POST("/hasil-ai/assess", controller.HasilAI.ProcessAssessment)

	// ========================
	// Jadwal Obat Endpoints
	// ========================
	api.POST("/jadwal-obat", controller.JadwalObat.Create)
	api.GET("/jadwal-obat", controller.JadwalObat.GetAll)
	api.GET("/jadwal-obat/obat/:obat_id", controller.JadwalObat.GetByObatID)
	api.GET("/jadwal-obat/:id", controller.JadwalObat.GetByID)
	api.PUT("/jadwal-obat/:id", controller.JadwalObat.Update)
	api.DELETE("/jadwal-obat/:id", controller.JadwalObat.Delete)

	// ========================
	// Lab (Legacy/Assessment) Endpoints
	// ========================
	api.POST("/lab", controller.Lab.Create)
	api.GET("/lab", controller.Lab.GetAll)
	api.GET("/lab/user/:user_id", controller.Lab.GetByUserID)
	api.POST("/assess", controller.Lab.Assess)

	// ========================
	// USG Tiroid Endpoints
	// ========================
	api.POST("/usg-tiroid", controller.USGTiroid.Create)
	api.GET("/usg-tiroid", controller.USGTiroid.GetAll)
	api.GET("/usg-tiroid/riwayat/:riwayat_id", controller.USGTiroid.GetByRiwayatID)
	api.GET("/usg-tiroid/user/:user_id", controller.USGTiroid.GetByUserID)
	api.GET("/usg-tiroid/:id", controller.USGTiroid.GetByID)
	api.PUT("/usg-tiroid/:id", controller.USGTiroid.Update)
	api.DELETE("/usg-tiroid/:id", controller.USGTiroid.Delete)
}