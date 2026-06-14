package helpers

import (
	"fmt"
	"strings"
)

// ParseDBError mengurai error database untuk memberikan pesan yang lebih user-friendly
func ParseDBError(err error) string {
	if err == nil {
		return ""
	}

	errStr := err.Error()

	// Error 1452 - Foreign Key Constraint Failed
	if strings.Contains(errStr, "1452") || strings.Contains(errStr, "foreign key constraint fails") {
		return "Foreign Key Error: Anda mencoba menginputkan data yang referensinya tidak ada di database. " +
			"Pastikan User/Riwayat/Laporan yang Anda referensikan sudah ada terlebih dahulu di database."
	}

	// Error 1406 - Data too long
	if strings.Contains(errStr, "1406") || strings.Contains(errStr, "Data too long") {
		return "Data terlalu panjang untuk field tersebut. Mohon kurangi input Anda."
	}

	// Error 1366 - Incorrect value
	if strings.Contains(errStr, "1366") || strings.Contains(errStr, "Incorrect value") {
		return "Format data tidak sesuai. Mohon periksa tipe data dan format yang dikirim."
	}

	// Duplicate entry
	if strings.Contains(errStr, "Duplicate entry") || strings.Contains(errStr, "1062") {
		return "Data sudah terdaftar. Mohon gunakan data yang berbeda."
	}

	// Parse error format Go
	if strings.Contains(errStr, "Scan error") {
		return "Kesalahan membaca data dari database. Mungkin format tanggal tidak sesuai. " +
			"Gunakan format YYYY-MM-DD."
	}

	return fmt.Sprintf("Database Error: %s", errStr)
}

// DebugUserCreateRequest membantu debugging saat membuat user
func DebugUserCreateRequest(nama, email, password string, tglLahir, tglDiagnosis interface{}) string {
	return fmt.Sprintf(`
=== DEBUG INFO: User Create Request ===
Nama: %s
Email: %s
Password: %s (length: %d)
TglLahir: %v
TglTerdiagnosis: %v
====================================
`, nama, email, password, len(password), tglLahir, tglDiagnosis)
}

// DebugRiwayatCreateRequest membantu debugging saat membuat riwayat
func DebugRiwayatCreateRequest(idUser uint, tanggal interface{}) string {
	return fmt.Sprintf(`
=== DEBUG INFO: Riwayat Create Request ===
IDUser: %d (Pastikan user dengan ID ini sudah ada di database!)
Tanggal: %v
====================================
`, idUser, tanggal)
}
