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
    cfg         *config.Config
    database    struct {
        MySQL *gorm.DB
    }
    repo        *repositories.Main
    usecase     *usecases.Main
    controller  *controllers.Main
    router      *echo.Echo
}

func New() *Main {
    return new(Main)
}

func (m *Main) Init() error {
    // 1. Load Config (TIDAK LAGI FATAL JIKA .ENV HILANG)
    viper.SetConfigFile(".env")
    if err := viper.ReadInConfig(); err != nil {
        fmt.Println("[INFO] File .env tidak ditemukan, menggunakan Environment System bawaan Railway.")
    } else {
        fmt.Println("[INFO] .env loaded successfully")
    }

    viper.AutomaticEnv() // Penting: Mengambil dari Railway Variables
    m.cfg = config.NewConfig()
    if err := viper.Unmarshal(m.cfg); err != nil {
        return fmt.Errorf("gagal memproses config: %v", err)
    }

    // 2. Setup Echo
    e := echo.New()
    e.Use(middleware.Logger())
    e.Use(middleware.Recover())
    e.Use(middleware.CORS())

    // 3. MySQL Setup
    mysqlCfg := m.cfg.Database.MySQL.Read
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

    var err error
    m.database.MySQL, err = database.GetConnection(args)
    if err != nil {
        return fmt.Errorf("gagal koneksi MySQL: %v", err)
    }
    fmt.Println("[INFO] MySQL connection established & AutoMigrate starting...")

    // 4. Auto Migrate
    models.SetupDatabase(m.database.MySQL)

    go usecases.StartMissedDoseChecker(m.database.MySQL)

    // 5. Inisialisasi layer
    m.repo = repositories.Init(repositories.Options{Config: m.cfg, DB: m.database.MySQL})
    m.usecase = usecases.Init(usecases.Options{Config: m.cfg, Repository: m.repo})
    m.controller = controllers.Init(controllers.Options{Config: m.cfg, UseCases: m.usecase})

    m.router = e
    routes.ConfigureRouter(e, m.controller)
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