// Package web содержит встроенные шаблоны и статические файлы.
package web

import (
	"embed"
	"io/fs"
)

//go:embed templates static
var FS embed.FS

// Static возвращает файловую систему со статикой (CSS, JS, изображения).
func Static() fs.FS {
	sub, err := fs.Sub(FS, "static")
	if err != nil {
		panic(err)
	}
	return sub
}
