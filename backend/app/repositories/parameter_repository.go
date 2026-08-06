package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type ParameterRepository interface {
	Create(parameter models.Parameter) (models.Parameter, error)
	GetByID(id uint) (models.Parameter, error)
	GetByNamaParameter(name string) (models.Parameter, error)
	GetAll() ([]models.Parameter, error)
	Update(id uint, parameter models.Parameter) (models.Parameter, error)
	Delete(id uint) error
}

type parameterRepository struct {
	db *gorm.DB
}

func NewParameterRepository(db *gorm.DB) ParameterRepository {
	return &parameterRepository{db: db}
}

func (r *parameterRepository) Create(parameter models.Parameter) (models.Parameter, error) {
	err := r.db.Create(&parameter).Error
	return parameter, err
}

func (r *parameterRepository) GetByID(id uint) (models.Parameter, error) {
	var parameter models.Parameter
	err := r.db.First(&parameter, id).Error
	return parameter, err
}

func (r *parameterRepository) GetByNamaParameter(name string) (models.Parameter, error) {
	var parameter models.Parameter
	err := r.db.Where("LOWER(nama_parameter) = LOWER(?)", name).First(&parameter).Error
	return parameter, err
}

func (r *parameterRepository) GetAll() ([]models.Parameter, error) {
	var parameter []models.Parameter
	err := r.db.Find(&parameter).Error
	return parameter, err
}

func (r *parameterRepository) Update(id uint, parameter models.Parameter) (models.Parameter, error) {
	err := r.db.Model(&models.Parameter{}).Where("id_parameter = ?", id).Updates(parameter).Error
	if err == nil {
		parameter, err = r.GetByID(id)
	}
	return parameter, err
}

func (r *parameterRepository) Delete(id uint) error {
	return r.db.Delete(&models.Parameter{}, id).Error
}
