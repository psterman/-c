package poc

import "testing"

func TestCapabilityForProviderKnownModes(t *testing.T) {
	fake := CapabilityForProvider("fake")
	if !fake.Stream || !fake.Action || !fake.Abort || fake.Experimental {
		t.Fatalf("fake capability wrong: %#v", fake)
	}
	if len(fake.Routes) != 1 || fake.Routes[0] != "r3" {
		t.Fatalf("fake routes: %#v", fake.Routes)
	}

	httpCap := CapabilityForProvider("http")
	if httpCap.Experimental {
		t.Fatal("http provider should not be experimental")
	}

	hermes := CapabilityForProvider("openai-chat")
	if !hermes.Experimental {
		t.Fatal("openai-chat should be experimental")
	}
}

func TestCapabilityForProviderUnknown(t *testing.T) {
	unk := CapabilityForProvider("mystery")
	if unk.Stream || unk.Action || unk.Abort {
		t.Fatalf("unknown provider should be inert: %#v", unk)
	}
	if !unk.Experimental {
		t.Fatal("unknown provider should be experimental")
	}
}

func TestHubStatusIncludesProviderCapability(t *testing.T) {
	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	hub.SetA2UIProvider("http", FakeA2UIProvider{})
	st := hub.Status()
	if st.A2UIProvider != "http" {
		t.Fatalf("provider name=%s", st.A2UIProvider)
	}
	if st.ProviderCapability.Provider != "http" {
		t.Fatalf("capability=%#v", st.ProviderCapability)
	}
}

func TestCapabilityForConfigDefaultsFake(t *testing.T) {
	cap := CapabilityForConfig(A2UIProviderConfig{})
	if cap.Provider != "fake" {
		t.Fatalf("default cap=%#v", cap)
	}
}
