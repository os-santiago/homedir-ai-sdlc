package implementation

import "time"

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

// QualityScore breaks down code quality across multiple dimensions
type QualityScore struct {
	Overall       float64  `json:"overall"`        // 0-10 weighted average
	Correctness   float64  `json:"correctness"`    // Does it solve the problem?
	Completeness  float64  `json:"completeness"`   // Meets all acceptance criteria?
	CodeQuality   float64  `json:"code_quality"`   // Clean, readable, maintainable?
	ErrorHandling float64  `json:"error_handling"` // Proper error handling?
	Testing       float64  `json:"testing"`        // Has tests?
	Issues        []string `json:"issues"`         // Specific problems found
}

// CalculateOverall computes weighted overall score from dimension scores
func (q *QualityScore) CalculateOverall() {
	q.Overall = (q.Correctness * 0.3) +
		(q.Completeness * 0.25) +
		(q.CodeQuality * 0.2) +
		(q.ErrorHandling * 0.15) +
		(q.Testing * 0.1)
}

// Attempt represents one generation iteration
type Attempt struct {
	Number int
	Code   string
	Score  QualityScore
}
