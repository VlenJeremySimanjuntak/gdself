# Solusi Error 1452 & Date Format Mismatch

## 📋 Ringkasan Masalah

Anda menghadapi dua masalah utama:

### 1. **Masalah Format Tanggal (Error 400 Bad Request)**
```
Format yang dikirim: 1998-08-12 (YYYY-MM-DD)
Format yang diterima Go: RFC3339 (1998-08-12T00:00:00Z)
```

**Solusi**: Custom Date Type dengan UnmarshalJSON

### 2. **Masalah Foreign Key (Error 1452)**
```
Foreign Key Constraint Failed: Anda mencoba memasukkan riwayat 
dengan id_user yang tidak ada di tabel user
```

**Solusi**: Validasi dan Error Handling yang lebih baik

---

## 🔧 Perubahan yang Telah Dilakukan

### 1. File Baru: `custom_date.go`
```go
// Custom unmarshaler untuk YYYY-MM-DD format
type CustomDate time.Time
```

### 2. Model Updates
- ✅ `User.go`: `*time.Time` → `*CustomDate`
- ✅ `Riwayat.go`: `*time.Time` → `*CustomDate`
- ✅ `LaporanLab.go`: `*time.Time` → `*CustomDate`

### 3. Error Handler: `db_error_parser.go`
Mengubah raw DB error menjadi pesan yang user-friendly

### 4. Enhanced User Controller
- Validasi lebih ketat
- Error message yang lebih informatif
- Debug info untuk troubleshooting

---

## 📝 URUTAN TESTING YANG BENAR

Ikuti urutan ini **PERSIS** atau foreign key error akan terjadi!

### Step 1: Buat User
```json
POST http://127.0.0.1:3000/api/users
Content-Type: application/json

{
  "nama": "Budi Santoso",
  "email": "budi.santoso@example.com",
  "password": "password123",
  "tgl_lahir": "1998-08-12",
  "jenis_kelamin": "L",
  "tgl_terdiagnosis": "2024-04-01"
}
```

**Response (catat id_user)**:
```json
{
  "status_code": 201,
  "message": "User berhasil dibuat",
  "data": {
    "id_user": 1,
    "nama": "Budi Santoso",
    ...
  }
}
```

### Step 2: Buat Riwayat (gunakan id_user dari Step 1)
```json
POST http://127.0.0.1:3000/api/riwayat
Content-Type: application/json

{
  "id_user": 1,
  "tanggal": "2026-05-02"
}
```

**Jika Error 1452 muncul**:
- Periksa: Apakah user dengan id=1 ada di database?
- Coba query: `SELECT * FROM user WHERE id_user = 1;`

### Step 3: Buat Laporan Lab
```json
POST http://127.0.0.1:3000/api/laporan-lab
Content-Type: application/json

{
  "id_user": 1,
  "tgl_periksa": "2026-05-02",
  "nama_lab": "Lab UNPAD"
}
```

**Response (catat id_laporan_lab)**:
```json
{
  "id_laporan_lab": 1,
  ...
}
```

### Step 4: Buat Wearable Data
```json
POST http://127.0.0.1:3000/api/wearable
Content-Type: application/json

{
  "id_riwayat": 1,
  "id_user": 1,
  "tgl_data": "2026-05-02",
  "waktu_data": "10:30:00",
  "heart_rate_rhr": 85,
  "stress_score": 55,
  "sleep_duration": 360
}
```

### Step 5: Buat Hasil Lab (gunakan id_laporan_lab & id_riwayat dari Step 2-3)
```json
POST http://127.0.0.1:3000/api/hasil-lab
Content-Type: application/json

{
  "id_laporan_lab": 1,
  "id_riwayat": 1,
  "nilai_hasil": 0.3,
  "rujukan_min": 0.4,
  "rujukan_max": 4.0,
  "parameters": [
    {
      "nama_parameter": "FT3",
      "satuan": "pmol/L",
      "kategori": "Thyroid",
      "nilai": 4.5
    },
    {
      "nama_parameter": "FT4",
      "satuan": "pmol/L",
      "kategori": "Thyroid",
      "nilai": 16.0
    },
    {
      "nama_parameter": "TSH",
      "satuan": "mIU/L",
      "kategori": "Thyroid",
      "nilai": 0.3
    }
  ]
}
```

---

## 🐛 Troubleshooting

### Error 1452: Foreign Key Constraint Failed

**Kemungkinan Penyebab:**
1. ❌ User dengan ID tertentu tidak ada → Buat user dulu
2. ❌ Truncate table tanpa reset ID → ID user baru bukan 1
3. ❌ Copypaste ID dari contoh tanpa sesuaikan

**Debugging:**
```sql
-- Cek user yang ada di database
SELECT id_user, nama, email FROM user;

-- Cek riwayat yang ada
SELECT * FROM riwayat;

-- Cek foreign keys
SHOW CREATE TABLE riwayat\G
```

### Error 400: Invalid Date Format

**Error Message Sebelumnya**:
```
json: cannot unmarshal string into Go struct field User.tgl_lahir of type time.Time
```

**Sekarang**:
```
{
  "error": "Invalid payload",
  "detail": "error parsing date: invalid format"
}
```

**Solusi**: Pastikan format tanggal adalah `YYYY-MM-DD`
- ✅ Benar: `"2026-05-02"`
- ❌ Salah: `"2026/05/02"` atau `"05-02-2026"`

---

## 📊 Request Body Template dengan Format Benar

Copy-paste langsung dari file `POSTMAN_COLLECTION.json` untuk memastikan format selalu benar!

```json
{
  "tgl_lahir": "1998-08-12",      // Format YYYY-MM-DD
  "tgl_terdiagnosis": "2024-04-01", // Format YYYY-MM-DD
  "tanggal": "2026-05-02"         // Format YYYY-MM-DD
}
```

---

## ✅ Checklist Sebelum Testing

- [ ] Semua files berhasil di-compile
- [ ] Database sudah bersih (optional: `DROP DATABASE; CREATE DATABASE;`)
- [ ] Port 3000 tidak digunakan (jalankan `go run cmd/main.go`)
- [ ] Gunakan Postman Collection yang sudah disediakan
- [ ] Ikuti urutan step 1-5 dengan benar
- [ ] Ganti id_user, id_report, id_riwayat sesuai response dari step sebelumnya

---

## 🔗 Related Files

- Model Definitions: `app/models/custom_date.go`
- Error Parser: `app/helpers/db_error_parser.go`
- User Controller: `app/controllers/user_controller.go`
- Updated Models: `app/models/user.go`, `riwayat.go`, `laporan_lab.go`

---

Jika masih ada error, silakan **share response error lengkap** beserta:
1. Request body yang dikirim
2. Database query hasil (SELECT * FROM table_name)
3. Timestamp saat error terjadi
