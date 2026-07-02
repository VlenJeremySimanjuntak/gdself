package routes

import (
	"time"
	appmiddleware "monitoring-service/app/middleware"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"monitoring-service/app/controllers"
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

	// =======================================================
	// 🟢 PUBLIC ENDPOINTS (Tidak Perlu Token JWT)
	// =======================================================
	// Auth
	api.POST("/auth/send-otp", controller.Auth.SendOTP)
	api.POST("/auth/verify-otp", controller.Auth.VerifyOTP)
	api.POST("/auth/google/check", controller.Auth.GoogleCheck)
	api.POST("/auth/google/complete", controller.Auth.GoogleComplete)
	api.POST("/auth/forgot-password", controller.Auth.ForgotPassword)
	api.POST("/auth/reset-password", controller.Auth.ResetPassword)
	api.POST("/auth/login", controller.User.Login)
	api.POST("/auth/register", controller.User.Create)
	api.POST("/auth/google", controller.User.GoogleLogin)
	
	// Alias User Auth (Sesuai kode awal Mas)
	api.POST("/login", controller.User.Login)
	api.POST("/users", controller.User.Create)


	// =======================================================
	// 🔴 PROTECTED ENDPOINTS (Wajib Pakai Token JWT)
	// =======================================================
	protected := api.Group("")

	// 🛡️ Pasang "Satpam" JWT di sini
	protected.Use(appmiddleware.JWTMiddleware())

	// ========================
	// User Endpoints
	// ========================
	protected.POST("/users/:id/avatar", controller.User.UploadAvatar)
	protected.GET("/users", controller.User.GetAll)
	protected.GET("/users/:id", controller.User.GetByID)
	protected.PUT("/users/:id", controller.User.Update)
	protected.DELETE("/users/:id", controller.User.Delete)

	// ========================
	// Riwayat Endpoints
	// ========================
	protected.POST("/riwayat", controller.Riwayat.Create)
	protected.GET("/riwayat", controller.Riwayat.GetAll)
	protected.GET("/riwayat/user/:user_id", controller.Riwayat.GetByUserID)
	protected.GET("/riwayat/:id", controller.Riwayat.GetByID)
	protected.PUT("/riwayat/:id", controller.Riwayat.Update)
	protected.DELETE("/riwayat/:id", controller.Riwayat.Delete)

	// ========================
	// Laporan Lab Endpoints
	// ========================
	protected.POST("/laporan-lab", controller.LaporanLab.Create)
	protected.GET("/laporan-lab", controller.LaporanLab.GetAll)
	protected.GET("/laporan-lab/user/:user_id", controller.LaporanLab.GetByUserID)
	protected.GET("/laporan-lab/:id", controller.LaporanLab.GetByID)
	protected.PUT("/laporan-lab/:id", controller.LaporanLab.Update)
	protected.DELETE("/laporan-lab/:id", controller.LaporanLab.Delete)

	// ========================
	// Monitoring Endpoint
	// ========================
	protected.GET("/monitoring/user/:user_id", controller.Monitoring.GetByUserID)

	// ========================
	// Obat Endpoints
	// ========================
	protected.POST("/obat", controller.Obat.Create)
	protected.GET("/obat", controller.Obat.GetAll)
	protected.GET("/obat/user/:user_id", controller.Obat.GetByUserID)
	protected.GET("/obat/:id", controller.Obat.GetByID)
	protected.PUT("/obat/:id", controller.Obat.Update)
	protected.DELETE("/obat/:id", controller.Obat.Delete)

	// ========================
	// Rekapan Obat
	// ========================
	protected.POST("/log-konsumsi", controller.LogKonsumsi.CatatKonsumsi)
	protected.GET("/log-konsumsi/jadwal/:jadwal_id", controller.LogKonsumsi.GetByJadwalID)

	// ========================
	// Wearable Endpoints
	// ========================
	protected.POST("/wearable", controller.Wearable.Create)
	protected.GET("/wearable", controller.Wearable.GetAll)
	protected.GET("/wearable/riwayat/:riwayat_id", controller.Wearable.GetByRiwayatID)
	protected.GET("/wearable/user/:user_id", controller.Wearable.GetByUserID)
	protected.GET("/wearable/:id", controller.Wearable.GetByID)
	protected.PUT("/wearable/:id", controller.Wearable.Update)
	protected.DELETE("/wearable/:id", controller.Wearable.Delete)

	// ========================
	// Hasil Lab Endpoints
	// ========================
	protected.POST("/hasil-lab", controller.HasilLab.Create)
	protected.GET("/hasil-lab", controller.HasilLab.GetAll)
	protected.GET("/hasil-lab/laporan/:laporan_id", controller.HasilLab.GetByLaporanLabID)
	protected.GET("/hasil-lab/riwayat/:riwayat_id", controller.HasilLab.GetByRiwayatID)
	protected.GET("/hasil-lab/user/:id_user/date/:tanggal", controller.HasilLab.GetByUserAndDate)
	protected.GET("/hasil-lab/riwayat/:riwayat_id/date/:date", controller.HasilLab.GetByRiwayatAndDate)
	protected.GET("/hasil-lab/:id", controller.HasilLab.GetByID)
	protected.PUT("/hasil-lab/:id", controller.HasilLab.Update)
	protected.DELETE("/hasil-lab/:id", controller.HasilLab.Delete)

	// ========================
	// Hasil AI Endpoints
	// ========================
	protected.POST("/hasil-ai/harian", controller.HasilAI.CreateHarian)
	protected.GET("/hasil-ai/harian/wearable/:wearable_id", controller.HasilAI.GetHarianByWearableID)
	protected.GET("/hasil-ai/harian/riwayat/:riwayat_id", controller.HasilAI.GetHarianByRiwayatID)
	protected.GET("/hasil-ai/harian/:id", controller.HasilAI.GetHarianByID)
	protected.GET("/hasil-ai/lab/laporan/:laporan_lab_id", controller.HasilAI.GetLabByLaporanLabID)
	protected.GET("/hasil-ai/lab/:id", controller.HasilAI.GetLabByID)
	protected.GET("/hasil-ai/tren/laporan/:laporan_lab_id", controller.HasilAI.GetTrenByLaporanLabID)
	protected.GET("/hasil-ai/tren/:id", controller.HasilAI.GetTrenByID)
	protected.POST("/hasil-ai/assess", controller.HasilAI.ProcessAssessment)
	protected.GET("/hasil-ai/lab/user/:user_id/param/:param", controller.HasilAI.GetLatestValidByUserAndParam) // ✅ pindah ke sini, pakai controller.HasilAI



	// ========================
	// Jadwal Obat Endpoints
	// ========================
	protected.POST("/jadwal-obat", controller.JadwalObat.Create)
	protected.GET("/jadwal-obat", controller.JadwalObat.GetAll)
	protected.GET("/jadwal-obat/obat/:obat_id", controller.JadwalObat.GetByObatID)
	protected.GET("/jadwal-obat/:id", controller.JadwalObat.GetByID)
	protected.PUT("/jadwal-obat/:id", controller.JadwalObat.Update)
	protected.DELETE("/jadwal-obat/:id", controller.JadwalObat.Delete)

	// ========================
	// Lab (Legacy/Assessment)
	// ========================
	protected.POST("/lab", controller.Lab.Create)
	protected.GET("/lab", controller.Lab.GetAll)
	protected.GET("/lab/user/:user_id", controller.Lab.GetByUserID)
	protected.POST("/assess", controller.Lab.Assess)

	// ========================
	// USG Tiroid Endpoints
	// ========================
	protected.POST("/usg-tiroid", controller.USGTiroid.Create)
	protected.GET("/usg-tiroid", controller.USGTiroid.GetAll)
	protected.GET("/usg-tiroid/riwayat/:riwayat_id", controller.USGTiroid.GetByRiwayatID)
	protected.GET("/usg-tiroid/user/:user_id", controller.USGTiroid.GetByUserID)
	protected.GET("/usg-tiroid/:id", controller.USGTiroid.GetByID)
	protected.PUT("/usg-tiroid/:id", controller.USGTiroid.Update)
	protected.DELETE("/usg-tiroid/:id", controller.USGTiroid.Delete)
}