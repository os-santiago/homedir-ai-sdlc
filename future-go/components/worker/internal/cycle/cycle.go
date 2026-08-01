package cycle

import "errors"

type Outcome string

const (
	Continue  Outcome = "continue"
	Completed Outcome = "completed"
	Failed    Outcome = "failed"
	Escalated Outcome = "needs-human"
)

type Attempt struct {
	Number             int      `json:"number"`
	ExitCode           int      `json:"exitCode"`
	TimedOut           bool     `json:"timedOut"`
	ChangedFiles       []string `json:"changedFiles"`
	ValidationPassed   bool     `json:"validationPassed"`
	ActionableFeedback []string `json:"actionableFeedback"`
	UnsafeOrAmbiguous  bool     `json:"unsafeOrAmbiguous"`
}

type Policy struct {
	MaximumAttempts     int `json:"maximumAttempts"`
	MaximumChangedFiles int `json:"maximumChangedFiles"`
}

type Decision struct {
	Outcome  Outcome `json:"outcome"`
	Reason   string  `json:"reason"`
	Reprompt bool    `json:"reprompt"`
}

func DefaultPolicy() Policy {
	return Policy{MaximumAttempts: 5, MaximumChangedFiles: 5}
}

func Evaluate(attempt Attempt, policy Policy) (Decision, error) {
	if attempt.Number < 1 || policy.MaximumAttempts < 1 || policy.MaximumChangedFiles < 1 {
		return Decision{}, errors.New("attempt and policy limits must be positive")
	}
	if attempt.UnsafeOrAmbiguous {
		return Decision{Outcome: Escalated, Reason: "Implementation requires unsafe or business-sensitive judgment."}, nil
	}
	if len(attempt.ChangedFiles) > policy.MaximumChangedFiles {
		return Decision{Outcome: Escalated, Reason: "Change exceeds the configured atomic file limit."}, nil
	}
	if attempt.TimedOut {
		return terminalOrRetry(attempt, policy, "Agent execution timed out."), nil
	}
	if attempt.ExitCode != 0 {
		return terminalOrRetry(attempt, policy, "Agent execution failed."), nil
	}
	if len(attempt.ChangedFiles) == 0 {
		return terminalOrRetry(attempt, policy, "Agent completed without producing changes."), nil
	}
	if !attempt.ValidationPassed {
		return terminalOrRetry(attempt, policy, "Scoped validation failed."), nil
	}
	if len(attempt.ActionableFeedback) > 0 {
		return terminalOrRetry(attempt, policy, "Actionable review feedback remains."), nil
	}
	return Decision{Outcome: Completed, Reason: "Implementation and scoped validation succeeded."}, nil
}

func terminalOrRetry(attempt Attempt, policy Policy, reason string) Decision {
	if attempt.Number >= policy.MaximumAttempts {
		return Decision{Outcome: Escalated, Reason: reason + " Maximum attempts reached."}
	}
	return Decision{Outcome: Continue, Reason: reason, Reprompt: true}
}
