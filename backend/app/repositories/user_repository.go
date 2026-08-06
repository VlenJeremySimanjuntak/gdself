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

	CollectAccountFiles(userID uint) (AccountFiles, error)
	HardDeleteAccountCascade(userID uint, email string) error
}

type AccountFiles struct {
	AvatarPath string   
	UsgPaths   []string 
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

func (r *userRepository) GetByIDSimple(id uint) (models.User, error) {
	var user models.User
	err := r.db.First(&user, id).Error
	return user, err
}

func (r *userRepository) GetByID(id uint) (models.User, error) {
	var user models.User
	err := r.db.
		Preload("Riwayat", func(db *gorm.DB) *gorm.DB {
			return db.Order("tanggal DESC").Limit(5) 
		}).
		Preload("Obat", func(db *gorm.DB) *gorm.DB {
			return db.Order("created_at DESC").Limit(10) 
		}).
		First(&user, id).Error
	return user, err
}

func (r *userRepository) GetByEmail(email string) (models.User, error) {
	var user models.User
	err := r.db.Where("email = ?", email).First(&user).Error
	return user, err
}

func (r *userRepository) GetAllSimple() ([]models.User, error) {
	var users []models.User
	err := r.db.Limit(100).Find(&users).Error 
	return users, err
}

func (r *userRepository) GetAll() ([]models.User, error) {
	var users []models.User
	err := r.db.
		Preload("Riwayat", func(db *gorm.DB) *gorm.DB {
			return db.Order("tanggal DESC").Limit(3) 
		}).
		Limit(50).
		Find(&users).Error
	return users, err
}

func (r *userRepository) Update(id uint, user models.User) (models.User, error) {
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

	return r.GetByIDSimple(id)
}

func (r *userRepository) Delete(id uint) error {
	return r.db.Delete(&models.User{}, id).Error
}

func (r *userRepository) CollectAccountFiles(userID uint) (AccountFiles, error) {
	var files AccountFiles

	var user models.User
	if err := r.db.Select("foto_profil").First(&user, userID).Error; err != nil {
		return files, err
	}
	files.AvatarPath = user.FotoProfil

	if err := r.db.
		Table("usg_tiroid").
		Joins("JOIN riwayat ON riwayat.id_riwayat = usg_tiroid.id_riwayat").
		Where("riwayat.id_user = ?", userID).
		Pluck("usg_tiroid.foto_path", &files.UsgPaths).Error; err != nil {
		return files, err
	}

	return files, nil
}

func (r *userRepository) HardDeleteAccountCascade(userID uint, email string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`
			DELETE FROM hasil_ai_harian
			WHERE id_wearable IN (
				SELECT id_wearable FROM wearable
				WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)
			)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM wearable
			WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM hasil_lab
			WHERE id_laporan_lab IN (
				SELECT id_laporan_lab FROM laporan_lab
				WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)
			)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM hasil_ai_lab
			WHERE id_laporan_lab IN (
				SELECT id_laporan_lab FROM laporan_lab
				WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)
			)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM hasil_ai_tren
			WHERE id_laporan_lab IN (
				SELECT id_laporan_lab FROM laporan_lab
				WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)
			)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM laporan_lab
			WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM usg_tiroid
			WHERE id_riwayat IN (SELECT id_riwayat FROM riwayat WHERE id_user = ?)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`DELETE FROM riwayat WHERE id_user = ?`, userID).Error; err != nil {
			return err
		}

		if err := tx.Exec(`
			DELETE FROM log_konsumsi_obat
			WHERE id_jadwal_obat IN (
				SELECT id_jadwal_obat FROM jadwal_obat
				WHERE id_obat IN (SELECT id_obat FROM obat WHERE id_user = ?)
			)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`
			DELETE FROM jadwal_obat
			WHERE id_obat IN (SELECT id_obat FROM obat WHERE id_user = ?)`, userID).Error; err != nil {
			return err
		}
		if err := tx.Exec(`DELETE FROM obat WHERE id_user = ?`, userID).Error; err != nil {
			return err
		}

		if email != "" {
			if err := tx.Exec(`DELETE FROM otp_codes WHERE email = ?`, email).Error; err != nil {
				return err
			}
		}

		if err := tx.Exec(`DELETE FROM user WHERE id_user = ?`, userID).Error; err != nil {
			return err
		}

		return nil
	})
}