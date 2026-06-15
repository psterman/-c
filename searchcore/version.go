package main

import "strings"

// BuildVersion is set at link time: -ldflags "-X main.BuildVersion=1.2.3"
var BuildVersion = "dev"

func coreVersion() string {
	v := strings.TrimSpace(BuildVersion)
	if v == "" {
		return "dev"
	}
	return v
}
