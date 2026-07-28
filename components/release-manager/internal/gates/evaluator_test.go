package gates

import "testing"

func greenSnapshot() Snapshot {
	return Snapshot{
		Checks: []Check{
			{Name: "tests", Status: "completed", Conclusion: "success", Required: true},
			{Name: "security", Status: "completed", Conclusion: "success", Required: true},
		},
		IssueCoveragePassed:       true,
		ValidationEvidencePresent: true,
		MaximumRemediation:        5,
	}
}

func TestEvaluateApprovesGreenPullRequest(t *testing.T) {
	got := Evaluate(greenSnapshot())
	if got.State != Approved {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateRequestsRemediationForFailingCheck(t *testing.T) {
	snapshot := greenSnapshot()
	snapshot.Checks[0].Conclusion = "failure"
	got := Evaluate(snapshot)
	if got.State != Remediation {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateEscalatesExhaustedRemediation(t *testing.T) {
	snapshot := greenSnapshot()
	snapshot.IssueCoveragePassed = false
	snapshot.RemediationAttempts = 5
	got := Evaluate(snapshot)
	if got.State != Escalated {
		t.Fatalf("got %#v", got)
	}
}

func TestEvaluateVerifiesSuccessfulProductionRelease(t *testing.T) {
	snapshot := Snapshot{Merged: true, ReleaseStatus: "completed", ReleaseConclusion: "success"}
	got := Evaluate(snapshot)
	if got.State != Verified {
		t.Fatalf("got %#v", got)
	}
}
