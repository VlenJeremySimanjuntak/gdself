package app

import (
	"fmt"
	"monitoring-service/app/controllers"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
	"monitoring-service/app/routes"
	"monitoring-service/app/usecases"
	"monitoring-service/pkg/config"
	"monitoring-service/pkg/database"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/spf13/viper"
	"gorm.io/gorm"
)

type Main struct {
	cfg      *config.Config
	database struct {
		MySQL *gorm.DB
	}
	repo       *repositories.Main
	usecase    *usecases.Main
	controller *controllers.Main
	router     *echo.Echo
}

func New() *Main {
	return new(Main)
}

func (m *Main) Init() error {
	fmt.Println("[INFO] Loading .env file...")
	viper.SetConfigFile(".env")
	err := viper.ReadInConfig()
	if err != nil {
		fmt.Printf("[ERROR] Failed to read .env: %v\n", err)
		return err
	}
	fmt.Println("[INFO] .env loaded successfully")

	m.cfg = config.NewConfig()
	viper.AutomaticEnv()
	err = viper.Unmarshal(m.cfg)
	if err != nil {
		fmt.Printf("[ERROR] Failed to unmarshal config: %v\n", err)
		return err
	}
	fmt.Printf("[INFO] Config loaded: %+v\n", m.cfg)

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// MySQL
	mysqlCfg := m.cfg.Database.MySQL.Read
	if mysqlCfg.Username == "" || mysqlCfg.URL == "" {
		fmt.Println("[ERROR] MySQL config incomplete")
		return fmt.Errorf("MySQL config incomplete")
	}

	args := &database.Args{
		Username:        mysqlCfg.Username,
		Password:        mysqlCfg.Password,
		Host:            mysqlCfg.URL,
		Port:            mysqlCfg.Port,
		Database:        mysqlCfg.Name,
		MaxIdleConns:    mysqlCfg.MaxIdleConns,
		MaxOpenConns:    mysqlCfg.MaxOpenConns,
		ConnMaxLifetime: mysqlCfg.MaxLifetime,
		Location:        mysqlCfg.Location,
		Timeout:         mysqlCfg.Timeout,
		DBType:          database.Mysql,
	}

	fmt.Printf("[INFO] Connecting MySQL with args: %+v\n", args)
	m.database.MySQL, err = database.GetConnection(args)
	if err != nil {
		fmt.Printf("[ERROR] Failed to connect MySQL: %v\n", err)
		return err
	}
	fmt.Println("[INFO] MySQL connection established")

	// AutoMigrate dengan urutan yang benar berdasarkan foreign key dependencies
	if err := m.database.MySQL.AutoMigrate(
		// 1. Base entities tanpa FK (utama)
		&models.User{},

		// 2. Entities dengan FK ke User
		&models.LaporanLab{},
		&models.Obat{},
		&models.Riwayat{},
		&models.Parameter{}, // Master parameter (FK target for HasilLab)

		// 3. Entities dengan FK ke entities lain
		&models.WearableRecord{}, // FK: Riwayat
		&models.HasilLab{},       // FK: LaporanLab, Parameter
		&models.JadwalObat{},     // FK: Obat

		// 4. HasilAI (tergantung entitas lain)
		&models.HasilAIHarian{},   // FK: Riwayat, Wearable
		&models.HasilAIGabungan{}, // FK: HasilLab, Riwayat, Wearable
	); err != nil {
		fmt.Printf("[ERROR] Failed to migrate database schema: %v\n", err)
		return err
	}
	fmt.Println("[INFO] Database schema migrated")

	// Note: previous attempts to DROP non-existent foreign keys produced
	// noisy warnings during startup. These explicit DROP statements were
	// removed because migrations are managed via SQL migration files.

	// Repos, usecase, controller
	m.repo = repositories.Init(repositories.Options{
		Config: m.cfg,
		DB:     m.database.MySQL,
	})
	m.usecase = usecases.Init(usecases.Options{
		Config:     m.cfg,
		Repository: m.repo,
	})
	m.controller = controllers.Init(controllers.Options{
		Config:   m.cfg,
		UseCases: m.usecase,
	})

	// Router
	m.router = e
	routes.ConfigureRouter(e, m.controller)
	fmt.Println("[INFO] Router configured")

	return nil
}

func (m *Main) Run() error {
	defer m.close()
	return m.router.Start(":" + m.cfg.ServicePort)
}

func (m *Main) close() {
	if m.database.MySQL != nil {
		if db, err := m.database.MySQL.DB(); err == nil {
			db.Close()
		}
	}
}
