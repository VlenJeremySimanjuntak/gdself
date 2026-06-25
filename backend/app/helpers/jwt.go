package helpers

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type JWTClaims struct {
	UserID uint   `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

// GenerateToken creates a signed JWT access token.
func GenerateToken(userID uint, email string, ttl time.Duration) (string, error) {
	// 1. Tanamkan kunci secara manual di sini!
	secret := "TokenAppSecretGraveDisease" 

	claims := JWTClaims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	// 2. Kunci rahasia akan dipakai untuk mencetak token di bawah ini
	return token.SignedString([]byte(secret))
}

// ParseToken verifies the token string and returns claims.
func ParseToken(tokenStr string) (*JWTClaims, error) {
	// 3. Tanamkan kunci yang sama di sini juga!
	secret := "TokenAppSecretGraveDisease"

	token, err := jwt.ParseWithClaims(tokenStr, &JWTClaims{}, func(t *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}