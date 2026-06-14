package main

import (
	"log"
	"monitoring-service/cmd/command"

	"github.com/joho/godotenv"
)

func main() {
	// Muat file .env sebelum command apa pun dieksekusi
	err := godotenv.Load()
	if err != nil {
		log.Println("Peringatan: File .env tidak ditemukan, menggunakan environment system bawaan")
	}

	command.Execute()
}