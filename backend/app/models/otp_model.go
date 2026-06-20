package models

import "time"

// Tabel untuk menyimpan OTP sementara
type OTPCode struct {
	ID        uint      `json:"id" gorm:"primaryKey;autoIncrement"`
	Email     string    `json:"email" gorm:"column:email;size:100;not null;index"`
	Code      string    `json:"code" gorm:"column:code;size:10;not null"`
	Type      string    `json:"type" gorm:"column:type;size:20;not null"` // "register" atau "reset_password"
	Used      bool      `json:"used" gorm:"column:used;default:false"`
	ExpiredAt time.Time `json:"expired_at" gorm:"column:expired_at;not null"`
	CreatedAt time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime"`
}

func (OTPCode) TableName() string {
	return "otp_codes"
}

// DTO
type SendOTPRequest struct {
	Email string `json:"email" binding:"required,email"`
	Type  string `json:"type" binding:"required"` // "register" atau "reset_password"
}

type VerifyOTPRequest struct {
	Email string `json:"email" binding:"required,email"`
	Code  string `json:"code" binding:"required"`
	Type  string `json:"type" binding:"required"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ResetPasswordRequest struct {
	Email       string `json:"email" binding:"required,email"`
	Code        string `json:"code" binding:"required"`
	NewPassword string `json:"new_password" binding:"required"`
}

// Request untuk complete Google registration
type GoogleCompleteRequest struct {
	IDToken         string      `json:"id_token" binding:"required"`
	Password        string      `json:"password" binding:"required"`
	JenisKelamin    string      `json:"jenis_kelamin" binding:"required"`
	TglLahir        *CustomDate `json:"tgl_lahir"`
	TglTerdiagnosis *CustomDate `json:"tgl_terdiagnosis"`
}

// Response untuk Google login — memberi tahu Flutter apakah user baru atau lama
type GoogleLoginResponse struct {
	IsNewUser bool                   `json:"is_new_user"`
	Token     string                 `json:"token,omitempty"`
	User      map[string]interface{} `json:"user,omitempty"`
	// Kalau new user, kirim data dari Google untuk pre-fill form
	GoogleEmail string `json:"google_email,omitempty"`
	GoogleName  string `json:"google_name,omitempty"`
	GooglePhoto string `json:"google_photo,omitempty"`
}