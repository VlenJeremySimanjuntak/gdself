package helpers

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/bcrypt"
)

const (
	passwordSaltLength = 16
	passwordKeyLength  = 32
	passwordTime       = 3
	passwordMemoryKiB  = 64 * 1024
	passwordThreads    = 2
	passwordVersion    = 19
)

// HashPassword membuat hash password modern berbasis argon2id.
// Format output menyimpan seluruh parameter agar bisa diverifikasi kembali:
// argon2id$v=19$m=65536,t=3,p=2$<salt>$<hash>
func HashPassword(password string) (string, error) {
	if password == "" {
		return "", errors.New("password tidak boleh kosong")
	}

	salt := make([]byte, passwordSaltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("gagal membuat salt password: %w", err)
	}

	hash := argon2.IDKey([]byte(password), salt, passwordTime, passwordMemoryKiB, passwordThreads, passwordKeyLength)

	encodedSalt := base64.RawStdEncoding.EncodeToString(salt)
	encodedHash := base64.RawStdEncoding.EncodeToString(hash)

	return fmt.Sprintf("argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		passwordVersion,
		passwordMemoryKiB,
		passwordTime,
		passwordThreads,
		encodedSalt,
		encodedHash,
	), nil
}

// VerifyPassword memvalidasi password input terhadap hash yang tersimpan.
// Mendukung format argon2id modern dan bcrypt legacy agar user lama tetap bisa login.
func VerifyPassword(storedHash, password string) error {
	if storedHash == "" {
		return errors.New("hash password kosong")
	}
	if password == "" {
		return errors.New("password tidak boleh kosong")
	}

	if strings.HasPrefix(storedHash, "argon2id$") {
		return verifyArgon2ID(storedHash, password)
	}

	// fallback untuk akun yang dibuat sebelum migrasi hashing baru
	if err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(password)); err == nil {
		return nil
	}

	return errors.New("password tidak cocok")
}

func verifyArgon2ID(storedHash, password string) error {
	parts := strings.Split(storedHash, "$")
	if len(parts) != 5 {
		return errors.New("format hash password tidak valid")
	}

	versionPart := strings.TrimPrefix(parts[1], "v=")
	version, err := strconv.Atoi(versionPart)
	if err != nil || version != passwordVersion {
		return errors.New("versi hash password tidak didukung")
	}

	var memory uint32
	var timeCost uint32
	var threads uint8
	params := strings.Split(parts[2], ",")
	for _, param := range params {
		kv := strings.SplitN(param, "=", 2)
		if len(kv) != 2 {
			return errors.New("parameter hash password tidak valid")
		}

		switch kv[0] {
		case "m":
			parsed, err := strconv.Atoi(kv[1])
			if err != nil || parsed <= 0 {
				return errors.New("parameter memory hash tidak valid")
			}
			memory = uint32(parsed)
		case "t":
			parsed, err := strconv.Atoi(kv[1])
			if err != nil || parsed <= 0 {
				return errors.New("parameter time hash tidak valid")
			}
			timeCost = uint32(parsed)
		case "p":
			parsed, err := strconv.Atoi(kv[1])
			if err != nil || parsed <= 0 || parsed > 255 {
				return errors.New("parameter threads hash tidak valid")
			}
			threads = uint8(parsed)
		default:
			return errors.New("parameter hash password tidak dikenal")
		}
	}

	salt, err := base64.RawStdEncoding.DecodeString(parts[3])
	if err != nil {
		return fmt.Errorf("gagal decode salt password: %w", err)
	}

	expectedHash, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return fmt.Errorf("gagal decode hash password: %w", err)
	}

	computedHash := argon2.IDKey([]byte(password), salt, timeCost, memory, threads, uint32(len(expectedHash)))
	if subtle.ConstantTimeCompare(expectedHash, computedHash) != 1 {
		return errors.New("password tidak cocok")
	}

	return nil
}
