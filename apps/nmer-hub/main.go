package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"nmer-wails/poc"
)

func main() {
	addr := strings.TrimSpace(os.Getenv("NMER_A2UI_BRIDGE_ADDR"))
	if addr == "" {
		addr = poc.DefaultWSAddr
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	hub := poc.NewHub(addr, poc.DefaultWSPath, nil, func(st poc.HubStatus) {
		log.Printf("[nmer-hub] status clients=%d running=%v provider=%s", st.ClientCount, st.Running, st.A2UIProvider)
	})
	provider, providerName, providerErr := poc.NewA2UIProvider(poc.A2UIProviderConfigFromEnv())
	if providerErr != nil {
		log.Printf("[nmer-hub] provider config rejected, using fake: %v", providerErr)
	} else {
		hub.SetA2UIProvider(providerName, provider)
	}
	if err := hub.Start(ctx); err != nil {
		log.Fatalf("[nmer-hub] start failed: %v", err)
	}
	log.Printf("[nmer-hub] listening http://%s%s (no WebView2)", hub.Status().Addr, poc.DefaultWSPath)
	<-ctx.Done()
	log.Printf("[nmer-hub] stopped")
}
