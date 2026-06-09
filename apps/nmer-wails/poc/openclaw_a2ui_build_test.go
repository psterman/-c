package poc

import "testing"

func TestBuildOpenClawTextSurfaceEnvelopes(t *testing.T) {
	envelopes, err := BuildOpenClawTextSurfaceEnvelopes(
		"card_1",
		"req-1",
		"surface-adp-1",
		"Title",
		"Answer body",
	)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if len(envelopes) != 3 {
		t.Fatalf("expected 3 envelopes, got %d", len(envelopes))
	}
	if !envelopes[len(envelopes)-1].Final {
		t.Fatalf("last envelope must be final")
	}
}
