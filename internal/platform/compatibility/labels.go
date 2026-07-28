package compatibility

// Labels preserves the public state projection used by the HomeDir worker
// during incremental migration. Durable workflow state must not depend on it.
var Labels = struct {
	Trigger, AdmissionReview, Accepted, Queued, Running, PROpen string
	WaitingChecks, FailingChecks, UnderReview, CoverageGap      string
	Approved, Merged, Failed, NeedsHuman, Rejected              string
}{
	Trigger:         "ready-to-implement",
	AdmissionReview: "scc-admission-review",
	Accepted:        "scc-accepted",
	Queued:          "scc-queued",
	Running:         "scc-running",
	PROpen:          "scc-pr-open",
	WaitingChecks:   "scc-waiting-checks",
	FailingChecks:   "scc-failing-checks",
	UnderReview:     "scc-under-review",
	CoverageGap:     "scc-coverage-gap",
	Approved:        "scc-approved",
	Merged:          "scc-merged",
	Failed:          "scc-failed",
	NeedsHuman:      "needs-human",
	Rejected:        "scc-rejected",
}
