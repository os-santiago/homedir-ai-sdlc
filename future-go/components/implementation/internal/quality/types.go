package quality

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
