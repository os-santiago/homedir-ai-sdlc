package service

import "testing"

func TestMetadataRequiresNameAndResponsibility(t *testing.T) {
	tests := []Metadata{
		{},
		{Name: "worker"},
		{Responsibility: "implementation"},
	}
	for _, metadata := range tests {
		if err := Run(metadata); err == nil {
			t.Fatalf("expected invalid metadata to fail: %#v", metadata)
		}
	}
}

func TestValueOrDefault(t *testing.T) {
	t.Setenv("AI_SDLC_TEST_VALUE", "configured")
	if got := valueOrDefault("AI_SDLC_TEST_VALUE", "fallback"); got != "configured" {
		t.Fatalf("got %q", got)
	}
	if got := valueOrDefault("AI_SDLC_MISSING_VALUE", "fallback"); got != "fallback" {
		t.Fatalf("got %q", got)
	}
}
