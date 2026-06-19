package models

import "time"

type User struct {
	IDUser          uint        `json:"id_user" gorm:"column:id_user;type:int unsigned;primaryKey;autoIncrement"`
	Nama            string      `json:"nama" gorm:"column:nama;size:100;not null"`
	Email           string      `json:"email" gorm:"column:email;size:100;uniqueIndex;not null"`
	Password        string      `json:"password" gorm:"column:password;size:255;not null"`
	Provider        string      `json:"provider" gorm:"column:provider;size:20;default:'local'"`
	TglLahir        *CustomDate `json:"tgl_lahir" gorm:"column:tgl_lahir;type:date"`
	JenisKelamin    string      `json:"jenis_kelamin" gorm:"column:jenis_kelamin;type:enum('L','P')"`
	TglTerdiagnosis *CustomDate `json:"tgl_terdiagnosis" gorm:"column:tgl_terdiagnosis;type:date"`
	FotoProfil      string      `json:"foto_profil" gorm:"column:foto_profil;type:varchar(255)"`
	UpdateAt        time.Time   `json:"update_at" gorm:"column:update_at;autoUpdateTime:milli"`

	// Relationships
	Riwayat []Riwayat `json:"riwayat,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
	Obat    []Obat    `json:"obat,omitempty" gorm:"foreignKey:IDUser;references:IDUser;constraint:OnUpdate:CASCADE,OnDelete:CASCADE"`
}

func (User) TableName() string {
	return "user"
}

// DTO untuk Create User
type CreateUserRequest struct {
	Nama            string      `json:"nama" binding:"required"`
	Email           string      `json:"email" binding:"required,email"`
	Password        string      `json:"password" binding:"required"`
	TglLahir        *CustomDate `json:"tgl_lahir"`
	JenisKelamin    string      `json:"jenis_kelamin" binding:"required,oneof=L P"`
	TglTerdiagnosis *CustomDate `json:"tgl_terdiagnosis"`
}

// DTO untuk Update User
type UpdateUserRequest struct {
	Nama            string      `json:"nama"`
	Email           string      `json:"email"`
	TglLahir        *CustomDate `json:"tgl_lahir"`
	JenisKelamin    string      `json:"jenis_kelamin"`
	TglTerdiagnosis *CustomDate `json:"tgl_terdiagnosis"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// DTO untuk Response Login
type LoginResponse struct {
	Token string        `json:"token"`
	User  UserLoginData `json:"user"`
}

// User data yang dikembalikan saat login (tanpa password)
type UserLoginData struct {
	IDUser          uint        `json:"id_user"`
	Nama            string      `json:"nama"`
	Email           string      `json:"email"`
	TglLahir        *CustomDate `json:"tgl_lahir"`
	JenisKelamin    string      `json:"jenis_kelamin"`
	TglTerdiagnosis *CustomDate `json:"tgl_terdiagnosis"`
	FotoProfil      string      `json:"foto_profil"`
	UpdateAt        time.Time   `json:"update_at"`
}

// DTO untuk Response Register
type RegisterResponse struct {
	Token string        `json:"token"`
	User  UserLoginData `json:"user"`
}