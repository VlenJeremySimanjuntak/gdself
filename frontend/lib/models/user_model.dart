import 'dart:convert';

class UserModel {
  final int idUser;
  final String nama;
  final String email;
  final String? jenisKelamin;
  final String? tglLahir;
  final String? tglTerdiagnosis;
  final String? fotoProfil; // ✅ TAMBAH: field foto profil
  final String? updateAt;

  UserModel({
    required this.idUser,
    required this.nama,
    required this.email,
    this.jenisKelamin,
    this.tglLahir,
    this.tglTerdiagnosis,
    this.fotoProfil,
    this.updateAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    idUser:          json['id_user']          ?? 0,
    nama:            json['nama']             ?? '',
    email:           json['email']            ?? '',
    jenisKelamin:    json['jenis_kelamin'],
    tglLahir:        json['tgl_lahir'],
    tglTerdiagnosis: json['tgl_terdiagnosis'],
    fotoProfil:      json['foto_profil'],     // ✅ TAMBAH
    updateAt:        json['update_at'],
  );

  Map<String, dynamic> toJson() => {
    'id_user':          idUser,
    'nama':             nama,
    'email':            email,
    'jenis_kelamin':    jenisKelamin,
    'tgl_lahir':        tglLahir,
    'tgl_terdiagnosis': tglTerdiagnosis,
    'foto_profil':      fotoProfil,           // ✅ TAMBAH
    'update_at':        updateAt,
  };

  String toJsonString() => jsonEncode(toJson());

  static UserModel fromJsonString(String raw) =>
      UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class AuthResponse {
  final String token;
  final UserModel user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: json['data']['token'] ?? '',
    user:  UserModel.fromJson(json['data']['user'] as Map<String, dynamic>),
  );
}