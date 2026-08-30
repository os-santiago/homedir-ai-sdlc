package quality

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Scorer parses AI review output into structured quality score
type Scorer struct{}

// NewScorer creates quality scorer
func NewScorer() *Scorer {
	return &Scorer{}
}

// ParseReview extracts quality score from AI review JSON response
func (s *Scorer) ParseReview(reviewText string) (QualityScore, error) {
	reviewText = extractJSON(reviewText)

	var rawScore struct {
		Correctness   float64  `json:"correctness"`
		Completeness  float64  `json:"completeness"`
		CodeQuality   float64  `json:"code_quality"`
		ErrorHandling float64  `json:"error_handling"`
		Testing       float64  `json:"testing"`
		Issues        []string `json:"issues"`
	}

	decoder := json.NewDecoder(strings.NewReader(reviewText))
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(&rawScore); err != nil {
		return QualityScore{}, fmt.Errorf("failed to parse review JSON: %w\nRaw text: %s", err, reviewText)
	}

	score := QualityScore{
		Correctness:   rawScore.Correctness,
		Completeness:  rawScore.Completeness,
		CodeQuality:   rawScore.CodeQuality,
		ErrorHandling: rawScore.ErrorHandling,
		Testing:       rawScore.Testing,
		Issues:        rawScore.Issues,
	}

	score.CalculateOverall()

	if err := validateScore(score); err != nil {
		return score, fmt.Errorf("invalid score values: %w", err)
	}

	return score, nil
}

// extractJSON finds JSON object in potentially markdown-wrapped text
func extractJSON(text string) string {
	text = strings.TrimSpace(text)

	// Remove markdown code blocks if present
	if strings.HasPrefix(text, "```json") {
		text = strings.TrimPrefix(text, "```json")
		text = strings.TrimSuffix(text, "```")
		text = strings.TrimSpace(text)
	} else if strings.HasPrefix(text, "```") {
		text = strings.TrimPrefix(text, "```")
		text = strings.TrimSuffix(text, "```")
		text = strings.TrimSpace(text)
	}

	// Find JSON object boundaries
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")

	if start != -1 && end != -1 && end > start {
		return text[start : end+1]
	}

	return text
}

// validateScore ensures all dimension scores are in valid range [0, 10]
func validateScore(score QualityScore) error {
	scores := map[string]float64{
		"correctness":    score.Correctness,
		"completeness":   score.Completeness,
		"code_quality":   score.CodeQuality,
		"error_handling": score.ErrorHandling,
		"testing":        score.Testing,
		"overall":        score.Overall,
	}

	for name, value := range scores {
		if value < 0 || value > 10 {
			return fmt.Errorf("%s score %.2f out of valid range [0, 10]", name, value)
		}
	}

	return nil
}

// GetCodeSample extracts first N characters of code for reference
func GetCodeSample(code string, maxLen int) string {
	if len(code) <= maxLen {
		return code
	}
	return code[:maxLen] + "..."
}
