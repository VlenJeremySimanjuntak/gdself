package main

import (
    "log"
    "monitoring-service/cmd/command"

    "github.com/joho/godotenv"
)

func main() {
    err := godotenv.Load()
    if err != nil {
        log.Println("Peringatan: File .env tidak ditemukan, menggunakan environment system bawaan")
        // Hapus log.Fatal agar aplikasi lanjut berjalan meski file tidak ada
    }
    
    command.Execute()
}