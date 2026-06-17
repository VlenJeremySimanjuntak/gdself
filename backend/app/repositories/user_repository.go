package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type UserRepository interface {
	Create(user models.User) (models.User, error)
	GetByID(id uint) (models.User, error)
	GetByIDSimple(id uint) (models.User, error)
	GetByEmail(email string) (models.User, error)
	GetAll() ([]models.User, error)
	GetAllSimple() ([]models.User, error)
	Update(id uint, user models.User) (models.User, error)
	Delete(id uint) error
}

type userRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) Create(user models.User) (models.User, error) {
	err := r.db.Create(&user).Error
	return user, err
}

// ✅ CEPAT: Tanpa Preload sama sekali
func (r *userRepository) GetByIDSimple(id uint) (models.User, error) {
	var user models.User
	err := r.db.First(&user, id).Error
	return user, err
}

// Hanya digunakan jika BENAR-BENAR butuh data relasi
func (r *userRepository) GetByID(id uint) (models.User, error) {
	var user models.User
	err := r.db.
		Preload("Riwayat", func(db *gorm.DB) *gorm.DB {
			return db.Order("tanggal DESC").Limit(5) // ✅ Batasi 5 riwayat terbaru
		}).
		Preload("Obat", func(db *gorm.DB) *gorm.DB {
			return db.Order("created_at DESC").Limit(10) // ✅ Batasi 10 obat
		}).
		First(&user, id).Error
	return user, err
}

// ✅ CEPAT: Hanya ambil user tanpa relasi
func (r *userRepository) GetByEmail(email string) (models.User, error) {
	var user models.User
	err := r.db.Where("email = ?", email).First(&user).Error
	return user, err
}

// ✅ CEPAT: Tanpa Preload
func (r *userRepository) GetAllSimple() ([]models.User, error) {
	var users []models.User
	err := r.db.Limit(100).Find(&users).Error // ✅ Batasi 100 user
	return users, err
}

// Hanya digunakan jika BENAR-BENAR butuh data relasi
func (r *userRepository) GetAll() ([]models.User, error) {
	var users []models.User
	err := r.db.
		Preload("Riwayat", func(db *gorm.DB) *gorm.DB {
			return db.Order("tanggal DESC").Limit(3) // ✅ Batasi 3 riwayat
		}).
		Limit(50). // ✅ Batasi 50 user
		Find(&users).Error
	return users, err
}

func (r *userRepository) Update(id uint, user models.User) (models.User, error) {
	// ✅ Update hanya field yang diperlukan
	updates := map[string]interface{}{}
	if user.Nama != "" {
		updates["nama"] = user.Nama
	}
	if user.Email != "" {
		updates["email"] = user.Email
	}
	if user.JenisKelamin != "" {
		updates["jenis_kelamin"] = user.JenisKelamin
	}
	if user.TglLahir != nil {
		updates["tgl_lahir"] = user.TglLahir
	}
	if user.TglTerdiagnosis != nil {
		updates["tgl_terdiagnosis"] = user.TglTerdiagnosis
	}
	if user.FotoProfil != "" {
		updates["foto_profil"] = user.FotoProfil
	}

	if len(updates) > 0 {
		err := r.db.Model(&models.User{}).Where("id_user = ?", id).Updates(updates).Error
		if err != nil {
			return user, err
		}
	}

	// ✅ Kembalikan data simple
	return r.GetByIDSimple(id)
}

func (r *userRepository) Delete(id uint) error {
	return r.db.Delete(&models.User{}, id).Error
}