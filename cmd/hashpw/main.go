package main

// Утилита для генерации bcrypt-хеша пароля:
//   go run ./cmd/hashpw -password admin123

import (
	"flag"
	"fmt"
	"os"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	password := flag.String("password", "", "пароль для хеширования")
	flag.Parse()

	if *password == "" {
		fmt.Fprintln(os.Stderr, "укажите -password")
		os.Exit(1)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(*password), bcrypt.DefaultCost)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	fmt.Println(string(hash))
}
