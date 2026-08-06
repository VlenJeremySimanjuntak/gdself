package helpers

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// MaxUploadSize adalah batas ukuran upload gambar (5 MB).
const MaxUploadSize int64 = 5 << 20

var allowedImageExt = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".webp": true,
}

// ValidateImageUpload memvalidasi ekstensi & ukuran dari header multipart.
func ValidateImageUpload(file *multipart.FileHeader) error {
	if file.Size > MaxUploadSize {
		return errors.New("ukuran file melebihi batas 5MB")
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	if !allowedImageExt[ext] {
		return errors.New("format tidak didukung (hanya jpg, jpeg, png, webp)")
	}
	return nil
}

// IsAllowedImageContent memeriksa MIME asli via magic bytes
// (cegah file berbahaya yang cuma diberi ekstensi .jpg).
func IsAllowedImageContent(head []byte) bool {
	switch http.DetectContentType(head) {
	case "image/jpeg", "image/png", "image/webp":
		return true
	}
	return false
}

// RandomFileName menghasilkan nama file acak dengan ekstensi tervalidasi.
func RandomFileName(originalName string) (string, error) {
	ext := strings.ToLower(filepath.Ext(originalName))
	if !allowedImageExt[ext] {
		return "", errors.New("format tidak didukung (hanya jpg, jpeg, png, webp)")
	}
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b) + ext, nil
}

// SafeUploadPath mengunci path ke dalam baseDir (anti path traversal).
// stored boleh berupa "usg/xxx.jpg" atau legacy "/uploads/usg/xxx.jpg".
func SafeUploadPath(baseDir, stored string) (string, error) {
	name := filepath.Base(filepath.Clean("/" + stored))
	if name == "." || name == string(os.PathSeparator) || name == "" {
		return "", errors.New("nama file tidak valid")
	}
	full := filepath.Join(baseDir, name)

	absBase, err := filepath.Abs(baseDir)
	if err != nil {
		return "", err
	}
	absFull, err := filepath.Abs(full)
	if err != nil {
		return "", err
	}
	if absFull != absBase && !strings.HasPrefix(absFull, absBase+string(os.PathSeparator)) {
		return "", errors.New("path di luar direktori upload")
	}
	return full, nil
}
