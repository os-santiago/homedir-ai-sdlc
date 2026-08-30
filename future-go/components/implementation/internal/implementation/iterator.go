package implementation

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/os-santiago/homedir-ai-sdlc/components/implementation/internal/quality"
	"github.com/os-santiago/homedir-ai-sdlc/components/implementation/internal/scagent"
)

// Iterator orchestrates multi-pass code generation with quality feedback
type Iterator struct {
	scAgent  *scagent.Client
	scorer   *quality.Scorer
	maxIter  int
	threshold float64
}

// NewIterator creates implementation iterator with configuration
func NewIterator() *Iterator {
	return &Iterator{
		scAgent:   scagent.NewClient(),
		scorer:    quality.NewScorer(),
		maxIter:   getEnvInt("MAX_IMPLEMENTATION_ITERATIONS", 3),
		threshold: getEnvFloat("QUALITY_THRESHOLD", 8.0),
	}
}

// Generate executes multi-pass code generation with quality gates
func (it *Iterator) Generate(req GenerateRequest) (GenerateResponse, error) {
	log.Printf("[iterator] Starting generation for issue #%d (max_iter=%d, threshold=%.1f)",
		req.IssueNumber, it.getMaxIter(req), it.getThreshold(req))

	var attempts []Attempt
	var feedbackHistory []AttemptFeedback
	var bestAttempt *Attempt

	maxIter := it.getMaxIter(req)
	threshold := it.getThreshold(req)

	for attemptNum := 1; attemptNum <= maxIter; attemptNum++ {
		log.Printf("[iterator] Attempt %d/%d", attemptNum, maxIter)

		// Generate code
		var code string
		var err error

		if attemptNum == 1 {
			// First attempt: use base prompt
			prompt := scagent.BuildImplementationPrompt(
				req.IssueNumber,
				req.IssueBody,
				req.AcceptanceCriteria,
			)
			code, err = it.scAgent.GenerateCode(prompt)
		} else {
			// Subsequent attempts: use feedback from previous attempt
			prevAttempt := attempts[len(attempts)-1]
			prompt := scagent.BuildFeedbackPrompt(
				req.IssueNumber,
				req.IssueBody,
				req.AcceptanceCriteria,
				prevAttempt.Code,
				prevAttempt.Score.Overall,
				prevAttempt.Score.Issues,
			)
			code, err = it.scAgent.GenerateCode(prompt)
		}

		if err != nil {
			log.Printf("[iterator] Generation failed at attempt %d: %v", attemptNum, err)
			return GenerateResponse{}, fmt.Errorf("generation failed at attempt %d: %w", attemptNum, err)
		}

		log.Printf("[iterator] Generated %d chars of code", len(code))

		// Quality check
		reviewText, err := it.scAgent.ReviewCode(code)
		if err != nil {
			log.Printf("[iterator] Review failed at attempt %d: %v", attemptNum, err)
			// Continue without score if review fails
			score := quality.QualityScore{
				Overall: 5.0,
				Issues:  []string{"Quality review failed"},
			}
			attempts = append(attempts, Attempt{
				Number: attemptNum,
				Code:   code,
				Score:  score,
			})
			continue
		}

		score, err := it.scorer.ParseReview(reviewText)
		if err != nil {
			log.Printf("[iterator] Failed to parse review at attempt %d: %v", attemptNum, err)
			// Use default score if parsing fails
			score = quality.QualityScore{
				Overall: 5.0,
				Issues:  []string{"Review parsing failed"},
			}
		}

		log.Printf("[iterator] Quality score: %.1f/10 (correctness=%.1f, completeness=%.1f, code_quality=%.1f, error_handling=%.1f, testing=%.1f)",
			score.Overall, score.Correctness, score.Completeness, score.CodeQuality, score.ErrorHandling, score.Testing)

		if len(score.Issues) > 0 {
			log.Printf("[iterator] Issues found: %v", score.Issues)
		}

		attempt := Attempt{
			Number: attemptNum,
			Code:   code,
			Score:  score,
		}
		attempts = append(attempts, attempt)

		// Track feedback
		feedbackHistory = append(feedbackHistory, AttemptFeedback{
			Attempt:    attemptNum,
			Score:      score.Overall,
			Issues:     score.Issues,
			CodeSample: quality.GetCodeSample(code, 200),
		})

		// Check if quality threshold met
		if score.Overall >= threshold {
			log.Printf("[iterator] ✓ Quality threshold met (%.1f >= %.1f), accepting attempt %d",
				score.Overall, threshold, attemptNum)
			bestAttempt = &attempt
			break
		}

		log.Printf("[iterator] Below threshold (%.1f < %.1f), will re-prompt with feedback",
			score.Overall, threshold)
	}

	// Select best attempt
	if bestAttempt == nil {
		// Threshold never met, select highest scoring attempt
		bestAttempt = &attempts[0]
		for i := range attempts {
			if attempts[i].Score.Overall > bestAttempt.Score.Overall {
				bestAttempt = &attempts[i]
			}
		}
		log.Printf("[iterator] ⚠ Threshold not met after %d iterations, selecting best attempt %d (score=%.1f)",
			len(attempts), bestAttempt.Number, bestAttempt.Score.Overall)
	}

	return GenerateResponse{
		Code:            bestAttempt.Code,
		QualityScore:    bestAttempt.Score.Overall,
		IterationsUsed:  len(attempts),
		FeedbackHistory: feedbackHistory,
		SelectedAttempt: bestAttempt.Number,
		Timestamp:       time.Now(),
	}, nil
}

func (it *Iterator) getMaxIter(req GenerateRequest) int {
	if req.MaxIterations > 0 {
		return req.MaxIterations
	}
	return it.maxIter
}

func (it *Iterator) getThreshold(req GenerateRequest) float64 {
	if req.QualityThreshold > 0 {
		return req.QualityThreshold
	}
	return it.threshold
}

func getEnvInt(key string, fallback int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return fallback
}

func getEnvFloat(key string, fallback float64) float64 {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseFloat(value, 64); err == nil {
			return parsed
		}
	}
	return fallback
}
