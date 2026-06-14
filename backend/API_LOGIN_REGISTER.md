# API Login & Register Documentation

## Base URL
```
http://your-backend-url/api
```

## Endpoints

### 1. Register (Create User)
**POST** `/auth/register` atau `/users`

#### Request Body
```json
{
  "nama": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "jenis_kelamin": "L",
  "tgl_lahir": "2000-01-01",
  "tgl_terdiagnosis": "2023-01-01"
}
```

#### Success Response (201 Created)
```json
{
  "status_code": 201,
  "message": "User berhasil dibuat",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id_user": 1,
      "nama": "John Doe",
      "email": "john@example.com",
      "jenis_kelamin": "L",
      "tgl_lahir": "2000-01-01",
      "tgl_terdiagnosis": "2023-01-01",
      "update_at": "2026-05-05T10:30:00Z"
    }
  }
}
```

#### Error Response (400 Bad Request)
```json
{
  "error": "email sudah terdaftar"
}
```

---

### 2. Login
**POST** `/auth/login` atau `/login`

#### Request Body
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

#### Success Response (200 OK)
```json
{
  "status_code": 200,
  "message": "Login berhasil",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id_user": 1,
      "nama": "John Doe",
      "email": "john@example.com",
      "jenis_kelamin": "L",
      "tgl_lahir": "2000-01-01",
      "tgl_terdiagnosis": "2023-01-01",
      "update_at": "2026-05-05T10:30:00Z"
    }
  }
}
```

#### Error Response (401 Unauthorized)
```json
{
  "error": "email atau password salah"
}
```

---

## JWT Token Usage

After successful login/register, use the token in subsequent API requests:

```
Authorization: Bearer {token}
```

Example:
```
GET /api/users/1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Flutter Implementation Example

### Update ApiService

```dart
class ApiService {
  final String baseUrl = 'http://your-backend-url/api';
  String? _token;

  Future<void> register({
    required String nama,
    required String email,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nama': nama,
          'email': email,
          'password': password,
          'jenis_kelamin': jenisKelamin,
          'tgl_lahir': tglLahir,
          'tgl_terdiagnosis': tglTerdiagnosis,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _token = data['data']['token'];
        // Save token to secure storage
        await _saveToken(_token!);
      } else {
        throw Exception('Register gagal');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['data']['token'];
        // Save token to secure storage
        await _saveToken(_token!);
      } else {
        throw Exception('Login gagal');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _saveToken(String token) async {
    // Implementasi simpan token ke secure storage
    // Gunakan flutter_secure_storage package
  }

  String get token => _token ?? '';
}
```

---

## Environment Variables (Backend)

Make sure these are set in your `.env` file:

```
JWT_SECRET=your-secret-key-here
```

---

## Token Expiration

- Default: 15 minutes
- Can be configured via environment variables

---

## CORS Configuration

The API accepts requests from all origins. Make sure to update this in production.

Current config:
- Allow Origins: `*`
- Allow Methods: `GET`, `POST`, `PUT`, `DELETE`, `OPTIONS`
- Allow Headers: `Content-Type`, `Authorization`
