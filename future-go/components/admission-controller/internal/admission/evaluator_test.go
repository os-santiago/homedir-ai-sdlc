package admission

import "testing"

func validIssue() Issue {
	return Issue{
		Repository:         "os-santiago/homedir",
		Number:             123,
		Revision:           "revision-1",
		Title:              "Improve community search performance",
		Body:               "Optimize the existing query while preserving current behavior and validation.",
		AcceptanceCriteria: []string{"Search returns the same results", "Latency is covered by a regression test"},
		RequestedBy:        "contributor",
		AuthorizedBy:       "maintainer",
	}
}

func TestEvaluateAcceptsAtomicSafeIssue(t *testing.T) {
	got := Evaluate(validIssue(), DefaultPolicy())
	if got.Decision != Accepted || got.Risk != "low" {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateRejectsProtectionBypass(t *testing.T) {
	issue := validIssue()
	issue.Body = "Please bypass branch protection and required reviews so changes merge immediately."
	got := Evaluate(issue, DefaultPolicy())
	if got.Decision != Rejected || got.Risk != "critical" {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateRequiresDecomposition(t *testing.T) {
	issue := validIssue()
	issue.AcceptanceCriteria = []string{"one", "two", "three", "four", "five", "six"}
	got := Evaluate(issue, DefaultPolicy())
	if got.Decision != NeedsDecomposition {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateEscalatesSecurityBoundary(t *testing.T) {
	issue := validIssue()
	issue.Body = "Change OIDC authentication roles and authorization behavior with appropriate tests."
	got := Evaluate(issue, DefaultPolicy())
	if got.Decision != NeedsHuman || got.Risk != "high" {
		t.Fatalf("got %#v", got)
	}
}
