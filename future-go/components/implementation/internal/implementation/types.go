package implementation

import (
	"time"

	"github.com/os-santiago/homedir-ai-sdlc/components/implementation/internal/quality"
)

// GenerateRequest represents code generation request with iteration support
type GenerateRequest struct {
	IssueNumber        int      `json:"issue_number"`
	IssueBody          string   `json:"issue_body"`
	AcceptanceCriteria []string `json:"acceptance_criteria"`
	MaxIterations      int      `json:"max_iterations,omitempty"`      // default: 3
	QualityThreshold   float64  `json:"quality_threshold,omitempty"`   // default: 8.0
}

// GenerateResponse contains best code version and iteration metadata
type GenerateResponse struct {
	Code             string            `json:"code"`
	QualityScore     float64           `json:"quality_score"`
	IterationsUsed   int               `json:"iterations_used"`
	FeedbackHistory  []AttemptFeedback `json:"feedback_history"`
	SelectedAttempt  int               `json:"selected_attempt"`
	Timestamp        time.Time         `json:"timestamp"`
}

// AttemptFeedback tracks each generation attempt and its quality assessment
type AttemptFeedback struct {
	Attempt    int      `json:"attempt"`
	Score      float64  `json:"score"`
	Issues     []string `json:"issues"`
	CodeSample string   `json:"code_sample"` // First 200 chars for reference
}

// Attempt represents one generation iteration
type Attempt struct {
	Number int
	Code   string
	Score  quality.QualityScore
}
