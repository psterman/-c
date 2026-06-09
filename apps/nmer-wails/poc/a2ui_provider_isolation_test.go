package poc

import "testing"

func TestExperimentalProviderDoesNotChangeFakeDefault(t *testing.T) {
	provider, name, err := NewA2UIProvider(A2UIProviderConfig{})
	if err != nil {
		t.Fatal(err)
	}
	if name != "fake" {
		t.Fatalf("default provider=%s", name)
	}
	if _, ok := provider.(FakeA2UIProvider); !ok {
		t.Fatalf("unexpected type %T", provider)
	}
	cap := CapabilityForProvider("openai-chat")
	if !cap.Experimental {
		t.Fatal("openai-chat must stay experimental")
	}
	fakeCap := CapabilityForProvider("fake")
	if fakeCap.Experimental {
		t.Fatal("fake must not be experimental")
	}
}

func TestOpenClawAdapterCapabilitySeparateFromHermes(t *testing.T) {
	hermes := CapabilityForProvider("openai-chat")
	httpCap := CapabilityForProvider("http")
	if hermes.Provider == httpCap.Provider {
		t.Fatal("hermes and http adapter should be distinct providers")
	}
	if !hermes.Experimental {
		t.Fatal("hermes path must be experimental")
	}
	if httpCap.Experimental {
		t.Fatal("http adapter path should not be experimental")
	}
}
