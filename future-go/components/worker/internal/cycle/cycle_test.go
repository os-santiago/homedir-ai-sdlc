package cycle

import "testing"

func TestEvaluateCompletesValidatedChange(t *testing.T) {
	got, err := Evaluate(Attempt{
		Number: 1, ChangedFiles: []string{"service.go"}, ValidationPassed: true,
	}, DefaultPolicy())
	if err != nil || got.Outcome != Completed {
		t.Fatalf("got=%#v err=%v", got, err)
	}
}

func TestEvaluateRepromptsNoop(t *testing.T) {
	got, err := Evaluate(Attempt{Number: 1, ValidationPassed: true}, DefaultPolicy())
	if err != nil || got.Outcome != Continue || !got.Reprompt {
		t.Fatalf("got=%#v err=%v", got, err)
	}
}

func TestEvaluateEscalatesAfterMaximumAttempts(t *testing.T) {
	got, err := Evaluate(Attempt{Number: 5, ExitCode: 1}, DefaultPolicy())
	if err != nil || got.Outcome != Escalated || got.Reprompt {
		t.Fatalf("got=%#v err=%v", got, err)
	}
}

func TestEvaluateContainsOversizedChange(t *testing.T) {
	got, err := Evaluate(Attempt{
		Number: 1, ChangedFiles: []string{"1", "2", "3", "4", "5", "6"},
	}, DefaultPolicy())
	if err != nil || got.Outcome != Escalated {
		t.Fatalf("got=%#v err=%v", got, err)
	}
}
