package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type UserRepository interface {
	Create(user models.User) (models.User, error)
	GetByID(id uint) (models.User, error)
	GetByEmail(email string) (models.User, error)
	GetAll() ([]models.User, error)
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

func (r *userRepository) GetByID(id uint) (models.User, error) {
	var user models.User
	err := r.db.Preload("Riwayat").Preload("LaporanLab").Preload("Obat").First(&user, id).Error
	return user, err
}

func (r *userRepository) GetByEmail(email string) (models.User, error) {
	var user models.User
	err := r.db.Where("email = ?", email).First(&user).Error
	return user, err
}

func (r *userRepository) GetAll() ([]models.User, error) {
	var users []models.User
	err := r.db.Preload("Riwayat").Preload("LaporanLab").Preload("Obat").Find(&users).Error
	return users, err
}

func (r *userRepository) Update(id uint, user models.User) (models.User, error) {
	err := r.db.Model(&models.User{}).Where("id_user = ?", id).Updates(user).Error
	if err == nil {
		user, err = r.GetByID(id)
	}
	return user, err
}

func (r *userRepository) Delete(id uint) error {
	return r.db.Delete(&models.User{}, id).Error
}
