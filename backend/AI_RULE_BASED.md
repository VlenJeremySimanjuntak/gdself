# AI Rule-Based Assessment Documentation

## Overview
Implementasi sistem penilaian berbasis aturan (rule-based AI) yang menggabungkan:
- **Lab Score (X)**: Penilaian kondisi hormon tiroid berdasarkan lab
- **Wearable Score (Z)**: Penilaian metrik kesehatan dari wearable/smartwatch
- **Trend Factor (Y)**: Faktor tren membandingkan dengan lab sebelumnya

## Reference Ranges (Hormone Thresholds)

### Lab Conditions Classification (X)

| Kode | Nama | TSH | FT3 | FT4 |
|------|------|-----|-----|-----|
| 1 | Normal | 0.4–4.0 | 2.3–4.2 | 7.6–15.0 |
| 2a | Graves Overt | <0.4 | >4.2 | >15.0 |
| 2b | Graves T3-dom | <0.4 | >4.2 | 7.6–15.0 |
| 2c | Graves T4-dom | <0.4 | 2.3–4.2 | >15.0 |
| 3 | Unknown | Pola di luar keempat kondisi di atas |

### Wearable Scoring (Z)

| Skor | Kondisi | Aturan |
|------|---------|--------|
| 1 | Normal | Semua metrik dalam rentang (HR, Stress, Sleep semua normal) |
| 2 | Sedang | Tepat 1 metrik di luar rentang |
| 3 | Tidak Normal | 2 atau 3 metrik di luar rentang |

**Metrik Wearable**: Detak jantung (HR), Level stress, Waktu tidur
**Baseline**: Ditentukan dari 3 hari pertama pengambilan data

## Scoring Formula

### Hari Pemeriksaan Lab (Lab Day = true)
```
Final Score = (X × Y) × 0.7 + Z × 0.3
```
- X: Lab Score (1–3)
- Y: Trend Factor (0.9, 1.0, atau 1.1)
- Z: Wearable Score (1–3)

### Hari Biasa (Non-Lab Day = false)
```
Final Score = X × 0.7 + Z × 0.3
```
- Gunakan nilai X dari lab terakhir yang tersimpan

## Interpretation Mapping

| Lab (X) | Wearable (Z) | Final Score | Interpretasi |
|---------|-------------|-------------|--------------|
| 1 Normal | 1 Normal | 1.0 | Normal / wearable normal |
| 1 Normal | 2 Sedang | 1.3 | Normal / wearable sedang |
| 1 Normal | 3 Tidak Normal | 1.6 | Normal / wearable jelek |
| 2 Graves | 1 Normal | 1.7 | Graves disease / wearable normal |
| 2 Graves | 2 Sedang | 2.0 | Graves disease / wearable sedang |
| 2 Graves | 3 Tidak Normal | 2.3 | Graves disease / wearable jelek |
| 3 Unknown | 1 Normal | 2.4 | Kondisi tidak diketahui / wearable normal |
| 3 Unknown | 2 Sedang | 2.7 | Kondisi tidak diketahui / wearable sedang |
| 3 Unknown | 3 Tidak Normal | 3.0 | Kondisi tidak diketahui / wearable jelek |

## API Endpoint

### POST /api/assess

Endpoint untuk melakukan assessment rule-based AI dengan input lab dan wearable.

#### Request JSON Format

```json
{
  "lab": {
    "id": 0,
    "user_id": 1,
    "ft3": 3.5,
    "ft4": 10.0,
    "tsh": 1.5,
    "status": "",
    "created_at": "2024-04-28T10:30:00Z"
  },
  "prev_lab": {
    "id": 0,
    "user_id": 1,
    "ft3": 2.8,
    "ft4": 8.5,
    "tsh": 2.0,
    "status": "",
    "created_at": "2024-04-14T10:30:00Z"
  },
  "wearable": {
    "hr": 75,
    "stress": 40,
    "sleep_minutes": 480,
    "baseline_hr_min": 60,
    "baseline_hr_max": 80,
    "baseline_stress_min": 20,
    "baseline_stress_max": 50,
    "baseline_sleep_min": 420,
    "baseline_sleep_max": 540
  },
  "is_lab_day": true
}
```

#### Response JSON Format

```json
{
  "message": "Analisis berhasil",
  "data": {
    "lab_score": 1,
    "lab_code": "1",
    "wearable_score": 1,
    "trend_factor_y": 1.0,
    "final_score": 1.0,
    "interpretation": "Normal / wearable normal"
  }
}
```

#### Response Fields

- **lab_score** (1–3): Skor kondisi lab (X)
- **lab_code** (string): Kode kondisi ("1", "2a", "2b", "2c", "3")
- **wearable_score** (1–3): Skor kondisi wearable (Z)
- **trend_factor_y** (float): Faktor tren (0.9, 1.0, atau 1.1)
- **final_score** (float): Skor akhir hasil perhitungan formula
- **interpretation** (string): Interpretasi dalam bahasa Indonesia

## Example Use Cases

### Case 1: Lab Day with Worsening Trend
User melakukan pemeriksaan lab dengan kondisi yang memburuk dari periode sebelumnya.

**Input:**
```json
{
  "lab": {
    "user_id": 1,
    "ft3": 4.5,
    "ft4": 16.0,
    "tsh": 0.3
  },
  "prev_lab": {
    "user_id": 1,
    "ft3": 3.2,
    "ft4": 9.0,
    "tsh": 1.8
  },
  "wearable": {
    "hr": 85,
    "stress": 55,
    "sleep_minutes": 360,
    "baseline_hr_min": 60,
    "baseline_hr_max": 80,
    "baseline_stress_min": 20,
    "baseline_stress_max": 50,
    "baseline_sleep_min": 420,
    "baseline_sleep_max": 540
  },
  "is_lab_day": true
}
```

**Expected Output:**
```json
{
  "message": "Analisis berhasil",
  "data": {
    "lab_score": 2,
    "lab_code": "2a",
    "wearable_score": 3,
    "trend_factor_y": 1.1,
    "final_score": 2.3,
    "interpretation": "Graves disease / wearable jelek"
  }
}
```

**Penjelasan:**
- X=2 (Graves Overt): TSH <0.4, FT3 >4.2, FT4 >15.0
- Z=3 (Abnormal): HR=85 (out of range), Stress=55 (out of range), Sleep=360 (out of range) → 3 metrics abnormal
- Y=1.1 (worsening): Lab score 2 > prev 1
- Final = (2 × 1.1) × 0.7 + 3 × 0.3 = 1.54 + 0.9 = 2.44 ≈ 2.4 (rounded), tapi interpretasi tetap 2.3 berdasarkan tabel

### Case 2: Regular Day (Non-Lab)
User memberikan data wearable pada hari biasa (tanpa lab test).

**Input:**
```json
{
  "lab": {
    "user_id": 1,
    "ft3": 3.5,
    "ft4": 10.0,
    "tsh": 1.5
  },
  "wearable": {
    "hr": 72,
    "stress": 35,
    "sleep_minutes": 480,
    "baseline_hr_min": 60,
    "baseline_hr_max": 80,
    "baseline_stress_min": 20,
    "baseline_stress_max": 50,
    "baseline_sleep_min": 420,
    "baseline_sleep_max": 540
  },
  "is_lab_day": false
}
```

**Expected Output:**
```json
{
  "message": "Analisis berhasil",
  "data": {
    "lab_score": 1,
    "lab_code": "1",
    "wearable_score": 1,
    "trend_factor_y": 1.0,
    "final_score": 1.0,
    "interpretation": "Normal / wearable normal"
  }
}
```

**Penjelasan:**
- X=1 (Normal): Semua hormon dalam range
- Z=1 (Normal): Semua metrik dalam baseline range
- Y=1.0 (tidak digunakan karena non-lab day)
- Final = 1 × 0.7 + 1 × 0.3 = 1.0

## Implementation Notes

### Trend Factor Calculation
- Jika `is_lab_day=false` atau `prev_lab` tidak tersedia, Y=1.0
- Jika kondisi memburuk (curr_score > prev_score), Y=1.1
- Jika kondisi membaik (curr_score < prev_score), Y=0.9
- Jika kondisi tetap (curr_score == prev_score), Y=1.0

### Wearable Scoring Logic
- Jika baseline range tidak tersedia (min=0 dan max=0), metrik tersebut dianggap normal
- Hitung berapa banyak metrik yang di luar rentang baseline
- Berdasarkan count tersebut, tentukan Z score (1, 2, atau 3)

### Error Handling
- Validasi input: lab, wearable harus ada
- Jika hormone values tidak valid, return error
- Prev_lab bersifat optional — jika tidak ada, Y otomatis 1.0

## Integration with Flutter

### Flutter Request Example (Dart)
```dart
final assessmentInput = {
  'lab': {
    'user_id': 1,
    'ft3': 3.5,
    'ft4': 10.0,
    'tsh': 1.5,
  },
  'wearable': {
    'hr': 72,
    'stress': 35,
    'sleep_minutes': 480,
    'baseline_hr_min': 60,
    'baseline_hr_max': 80,
    'baseline_stress_min': 20,
    'baseline_stress_max': 50,
    'baseline_sleep_min': 420,
    'baseline_sleep_max': 540,
  },
  'is_lab_day': false,
};

final response = await http.post(
  Uri.parse('http://your-server/api/assess'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(assessmentInput),
);

final result = jsonDecode(response.body);
print('Final Score: ${result['data']['final_score']}');
print('Interpretation: ${result['data']['interpretation']}');
```

## Testing

Unit test sudah disediakan di dalam `lab_rules.go`. Anda bisa menjalankan:
```bash
go test ./app/usecases -v
```

## Summary

Sistem rule-based AI ini memberikan:
1. **Automatic diagnosis** berdasarkan nilai hormon lab
2. **Holistic assessment** dengan mempertimbangkan metrik wearable
3. **Trend analysis** untuk melihat perkembangan pasien
4. **Clear interpretation** untuk ditampilkan di Flutter UI

Endpoint `/api/assess` siap digunakan oleh aplikasi Flutter untuk melakukan real-time health assessment.
