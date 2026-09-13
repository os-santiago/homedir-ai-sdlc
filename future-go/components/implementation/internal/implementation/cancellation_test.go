package implementation

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type blockingAgent struct {
	generations, reviews int
	blockReview          bool
}

func TestTimeoutConfiguration(t *testing.T) {
	for _, value := range []string{"0", "-1", "invalid", "86401"} {
		t.Setenv("IMPLEMENTATION_TIMEOUT_SECONDS", value)
		if got := NewHandler().timeout; got != 1800*time.Second {
			t.Fatalf("value=%s timeout=%s", value, got)
		}
	}

	t.Setenv("IMPLEMENTATION_TIMEOUT_SECONDS", "60")
	if got := NewHandler().timeout; got != time.Minute {
		t.Fatalf("timeout=%s", got)
	}
}

func (a *blockingAgent) GenerateCode(ctx context.Context, _ string) (string, error) {
	a.generations++
	if a.blockReview {
		return "code", nil
	}
	<-ctx.Done()
	return "", ctx.Err()
}
func (a *blockingAgent) ReviewCode(ctx context.Context, _ string) (string, error) {
	a.reviews++
	<-ctx.Done()
	return "", ctx.Err()
}

func TestCancellationStopsIterations(t *testing.T) {
	for _, review := range []bool{false, true} {
		a := &blockingAgent{blockReview: review}
		it := &Iterator{scAgent: a, maxIter: 3}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
		_, err := it.Generate(ctx, GenerateRequest{IssueNumber: 59, IssueBody: "test"})
		cancel()
		if !errors.Is(err, context.DeadlineExceeded) || a.generations != 1 {
			t.Fatalf("review=%v: err=%v generations=%d", review, err, a.generations)
		}
		if review && a.reviews != 1 {
			t.Fatalf("reviews=%d", a.reviews)
		}
	}
}

func TestAlreadyCanceledRequestDoesNotStartAgent(t *testing.T) {
	a := &blockingAgent{}
	it := &Iterator{scAgent: a, maxIter: 3}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := it.Generate(ctx, GenerateRequest{})
	if !errors.Is(err, context.Canceled) || a.generations != 0 {
		t.Fatalf("err=%v calls=%d", err, a.generations)
	}
}

func TestHTTPServerDeadline(t *testing.T) {
	a := &blockingAgent{}
	h := &Handler{iterator: &Iterator{scAgent: a, maxIter: 3}, timeout: 20 * time.Millisecond}
	r := httptest.NewRequest(http.MethodPost, "/api/implementation/generate", strings.NewReader(`{"issue_number":59,"issue_body":"test"}`))
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusGatewayTimeout {
		t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
	}
}

func TestHTTPParentCancellation(t *testing.T) {
	a := &blockingAgent{}
	h := &Handler{iterator: &Iterator{scAgent: a, maxIter: 3}, timeout: time.Hour}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	r := httptest.NewRequest(http.MethodPost, "/api/implementation/generate", strings.NewReader(`{"issue_number":59,"issue_body":"test"}`)).WithContext(ctx)
	h.ServeHTTP(httptest.NewRecorder(), r)
	if a.generations != 0 {
		t.Fatalf("calls=%d", a.generations)
	}
}
