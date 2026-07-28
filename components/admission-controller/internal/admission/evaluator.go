package admission

import (
	"regexp"
	"strings"
)

type Decision string

const (
	Accepted           Decision = "accepted"
	Rejected           Decision = "rejected"
	NeedsClarification Decision = "needs-clarification"
	NeedsHuman         Decision = "needs-human"
	NeedsDecomposition Decision = "requires-decomposition"
)

type Issue struct {
	Repository         string   `json:"repository"`
	Number             int      `json:"number"`
	Revision           string   `json:"revision"`
	Title              string   `json:"title"`
	Body               string   `json:"body"`
	AcceptanceCriteria []string `json:"acceptanceCriteria"`
	RequestedBy        string   `json:"requestedBy"`
	AuthorizedBy       string   `json:"authorizedBy"`
}

type Policy struct {
	Version                    string `json:"version"`
	MinimumTitleLength         int    `json:"minimumTitleLength"`
	MinimumBodyLength          int    `json:"minimumBodyLength"`
	MaximumAcceptanceCriteria  int    `json:"maximumAcceptanceCriteria"`
	RequireAcceptanceCriteria  bool   `json:"requireAcceptanceCriteria"`
	RequireAuthorizedAdmission bool   `json:"requireAuthorizedAdmission"`
}

type Result struct {
	Decision      Decision `json:"decision"`
	Risk          string   `json:"risk"`
	Reasons       []string `json:"reasons"`
	RequiredGates []string `json:"requiredGates"`
	PolicyVersion string   `json:"policyVersion"`
}

var destructivePatterns = compileAll(
	`\bdelete\s+(all|prod|production|database|data|users?)\b`,
	`\bdrop\s+(database|table|schema)\b`,
	`\bwipe\s+(data|database|server|prod|production)\b`,
	`\bdisable\s+(auth|authentication|authorization|security|checks?)\b`,
	`\bbypass\s+(branch protection|rulesets?|reviews?|checks?|security)\b`,
	`\bexpose\s+(secret|token|password|key)\b`,
	`\bforce\s+push\b`,
	`\b--admin\b`,
)

var guardrailDegradationPatterns = compileAll(
	`\bremove\s+(tests?|validation|monitoring|logging)\b`,
	`\bignore\s+(security|checks?|tests?|lint|validation)\b`,
)

var elevatedRiskPatterns = compileAll(
	`\b(auth|authentication|authorization|oauth|oidc|permission|role)\b`,
	`\b(database migration|schema migration|personal data|pii)\b`,
	`\b(security policy|cryptography|encryption|secret rotation)\b`,
)

func DefaultPolicy() Policy {
	return Policy{
		Version:                    "1.0.0",
		MinimumTitleLength:         8,
		MinimumBodyLength:          30,
		MaximumAcceptanceCriteria:  5,
		RequireAcceptanceCriteria:  true,
		RequireAuthorizedAdmission: true,
	}
}

func Evaluate(issue Issue, policy Policy) Result {
	result := Result{
		Decision:      Accepted,
		Risk:          "low",
		RequiredGates: []string{"tests", "quality", "security", "issue-coverage"},
		PolicyVersion: policy.Version,
	}
	text := strings.ToLower(issue.Title + "\n" + issue.Body)

	if issue.Repository == "" || issue.Number < 1 || issue.Revision == "" {
		result.Decision = NeedsClarification
		result.Reasons = append(result.Reasons, "Repository, issue number and revision are required.")
	}
	if len(strings.TrimSpace(issue.Title)) < policy.MinimumTitleLength ||
		len(strings.TrimSpace(issue.Body)) < policy.MinimumBodyLength {
		result.Decision = NeedsClarification
		result.Reasons = append(result.Reasons, "Issue is too short to implement safely.")
	}
	if policy.RequireAcceptanceCriteria && len(issue.AcceptanceCriteria) == 0 {
		result.Decision = NeedsClarification
		result.Reasons = append(result.Reasons, "Explicit acceptance criteria are required.")
	}
	if policy.RequireAuthorizedAdmission && strings.TrimSpace(issue.AuthorizedBy) == "" {
		result.Decision = NeedsHuman
		result.Reasons = append(result.Reasons, "Admission requires an authorized actor.")
	}
	if matchesAny(destructivePatterns, text) {
		result.Decision = Rejected
		result.Risk = "critical"
		result.Reasons = append(result.Reasons, "Issue requests destructive, secret-disclosing or protection-bypass work.")
		return result
	}
	if matchesAny(guardrailDegradationPatterns, text) {
		result.Decision = NeedsHuman
		result.Risk = "high"
		result.Reasons = append(result.Reasons, "Issue may weaken operational or engineering guardrails.")
	}
	if len(issue.AcceptanceCriteria) > policy.MaximumAcceptanceCriteria {
		result.Decision = NeedsDecomposition
		result.Reasons = append(result.Reasons, "Issue exceeds the configured atomic work limit.")
	}
	if matchesAny(elevatedRiskPatterns, text) {
		result.Risk = "high"
		result.RequiredGates = append(result.RequiredGates, "human-security-review")
		if result.Decision == Accepted {
			result.Decision = NeedsHuman
			result.Reasons = append(result.Reasons, "Security or data boundary changes require human review.")
		}
	}
	if len(result.Reasons) == 0 {
		result.Reasons = []string{"No blocking admission risks detected."}
	}
	return result
}

func compileAll(patterns ...string) []*regexp.Regexp {
	compiled := make([]*regexp.Regexp, 0, len(patterns))
	for _, pattern := range patterns {
		compiled = append(compiled, regexp.MustCompile(pattern))
	}
	return compiled
}

func matchesAny(patterns []*regexp.Regexp, text string) bool {
	for _, pattern := range patterns {
		if pattern.MatchString(text) {
			return true
		}
	}
	return false
}
