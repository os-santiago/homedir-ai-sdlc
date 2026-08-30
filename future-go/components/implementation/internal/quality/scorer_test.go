package quality

import (
	"testing"

	"github.com/os-santiago/homedir-ai-sdlc/components/implementation/internal/implementation"
)

func TestParseReview_ValidJSON(t *testing.T) {
	scorer := NewScorer()

	reviewText := `{
  "correctness": 8.5,
  "completeness": 9.0,
  "code_quality": 7.5,
  "error_handling": 8.0,
  "testing": 6.0,
  "issues": ["Missing tests for edge case X", "Error handling incomplete in function Y"]
}`

	score, err := scorer.ParseReview(reviewText)
	if err != nil {
		t.Fatalf("ParseReview failed: %v", err)
	}

	if score.Correctness != 8.5 {
		t.Errorf("Expected correctness 8.5, got %.1f", score.Correctness)
	}
	if score.Completeness != 9.0 {
		t.Errorf("Expected completeness 9.0, got %.1f", score.Completeness)
	}
	if score.CodeQuality != 7.5 {
		t.Errorf("Expected code_quality 7.5, got %.1f", score.CodeQuality)
	}
	if score.ErrorHandling != 8.0 {
		t.Errorf("Expected error_handling 8.0, got %.1f", score.ErrorHandling)
	}
	if score.Testing != 6.0 {
		t.Errorf("Expected testing 6.0, got %.1f", score.Testing)
	}

	expectedOverall := (8.5 * 0.3) + (9.0 * 0.25) + (7.5 * 0.2) + (8.0 * 0.15) + (6.0 * 0.1)
	if score.Overall != expectedOverall {
		t.Errorf("Expected overall %.2f, got %.2f", expectedOverall, score.Overall)
	}

	if len(score.Issues) != 2 {
		t.Errorf("Expected 2 issues, got %d", len(score.Issues))
	}
}

func TestParseReview_MarkdownWrapped(t *testing.T) {
	scorer := NewScorer()

	reviewText := "```json\n" + `{
  "correctness": 9.0,
  "completeness": 8.5,
  "code_quality": 9.0,
  "error_handling": 8.5,
  "testing": 7.0,
  "issues": []
}` + "\n```"

	score, err := scorer.ParseReview(reviewText)
	if err != nil {
		t.Fatalf("ParseReview failed: %v", err)
	}

	if score.Correctness != 9.0 {
		t.Errorf("Expected correctness 9.0, got %.1f", score.Correctness)
	}
	if len(score.Issues) != 0 {
		t.Errorf("Expected 0 issues, got %d", len(score.Issues))
	}
}

func TestParseReview_InvalidJSON(t *testing.T) {
	scorer := NewScorer()

	reviewText := "This is not JSON"

	_, err := scorer.ParseReview(reviewText)
	if err == nil {
		t.Error("Expected error for invalid JSON, got nil")
	}
}

func TestParseReview_OutOfRange(t *testing.T) {
	scorer := NewScorer()

	reviewText := `{
  "correctness": 15.0,
  "completeness": 9.0,
  "code_quality": 7.5,
  "error_handling": 8.0,
  "testing": 6.0,
  "issues": []
}`

	_, err := scorer.ParseReview(reviewText)
	if err == nil {
		t.Error("Expected error for out-of-range score, got nil")
	}
}

func TestQualityScore_CalculateOverall(t *testing.T) {
	score := implementation.QualityScore{
		Correctness:   10.0,
		Completeness:  10.0,
		CodeQuality:   10.0,
		ErrorHandling: 10.0,
		Testing:       10.0,
	}

	score.CalculateOverall()

	if score.Overall != 10.0 {
		t.Errorf("Expected overall 10.0 for perfect scores, got %.2f", score.Overall)
	}
}

func TestGetCodeSample(t *testing.T) {
	code := "package main\n\nimport \"fmt\"\n\nfunc main() {\n  fmt.Println(\"Hello, World!\")\n}"

	sample := GetCodeSample(code, 20)
	if len(sample) > 23 { // 20 + "..."
		t.Errorf("Sample too long: %d chars", len(sample))
	}

	shortCode := "package main"
	sample = GetCodeSample(shortCode, 50)
	if sample != shortCode {
		t.Errorf("Expected unchanged code for short input, got %s", sample)
	}
}
