package repositories

import (
	"monitoring-service/app/models"
	"time"

	"gorm.io/gorm"
)

type OTPRepository interface {
	Create(otp models.OTPCode) (models.OTPCode, error)
	GetByEmailAndType(email, otpType string) (models.OTPCode, error)
	GetUsedOTPByEmail(email, otpType string) (models.OTPCode, error)
	MarkAsUsed(id uint) error
	DeleteExpired() error
	DeleteByEmail(email, otpType string) error
}

type otpRepository struct {
	db *gorm.DB
}

func NewOTPRepository(db *gorm.DB) OTPRepository {
	return &otpRepository{db: db}
}

func (r *otpRepository) Create(otp models.OTPCode) (models.OTPCode, error) {
	err := r.db.Create(&otp).Error
	return otp, err
}

func (r *otpRepository) GetByEmailAndType(email, otpType string) (models.OTPCode, error) {
	var otp models.OTPCode
	err := r.db.Where("email = ? AND type = ? AND used = false AND expired_at > ?",
		email, otpType, time.Now()).
		Order("created_at DESC").
		First(&otp).Error
	return otp, err
}

func (r *otpRepository) MarkAsUsed(id uint) error {
	return r.db.Model(&models.OTPCode{}).Where("id = ?", id).Update("used", true).Error
}

func (r *otpRepository) DeleteExpired() error {
	return r.db.Where("expired_at < ?", time.Now()).Delete(&models.OTPCode{}).Error
}

func (r *otpRepository) DeleteByEmail(email, otpType string) error {
	return r.db.Where("email = ? AND type = ?", email, otpType).Delete(&models.OTPCode{}).Error
}

func (r *otpRepository) GetUsedOTPByEmail(email, otpType string) (models.OTPCode, error) {
    var otp models.OTPCode
    err := r.db.Where(
        "email = ? AND type = ? AND used = ?",
        email, otpType, true,
    ).Order("created_at DESC").First(&otp).Error
    return otp, err
}