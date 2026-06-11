//go:build !windows

package main

import "net/http"

func handleFullTextRoots(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not supported", http.StatusNotImplemented)
}
