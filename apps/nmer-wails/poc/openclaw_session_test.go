package poc

import "testing"

func TestOpenClawCanonicalSessionKey(t *testing.T) {
	if got := OpenClawCanonicalSessionKey("main"); got != "agent:main:main" {
		t.Fatalf("main: got %q", got)
	}
	if got := OpenClawCanonicalSessionKey("agent:main:foo"); got != "agent:main:foo" {
		t.Fatalf("agent prefix: got %q", got)
	}
}

func TestOpenClawSessionKeyNamespacesDistinct(t *testing.T) {
	cardID := "card_123_456"
	cp := OpenClawSessionKeyForCard(cardID, OpenClawNamespaceCP)
	adp := OpenClawSessionKeyForCard(cardID, OpenClawNamespaceAdapter)
	if cp == adp {
		t.Fatalf("cp and adp keys must differ: %q", cp)
	}
	if !IsOpenClawCPSessionKey(cp) {
		t.Fatalf("expected cp key, got %q", cp)
	}
	if !IsOpenClawAdapterSessionKey(adp) {
		t.Fatalf("expected adp key, got %q", adp)
	}
}

func TestOpenClawCardIDSlug(t *testing.T) {
	if got := openClawCardIDSlug("card_AB-12"); got != "AB-12" {
		t.Fatalf("slug: got %q", got)
	}
}
