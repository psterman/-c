//go:build !windows

package main

import "fmt"

func main() {
	fmt.Println("native-drop-bridge is windows-only")
}
