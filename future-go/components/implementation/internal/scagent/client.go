package scagent

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Client wraps sc-agent-cli execution for code generation and quality review
type Client struct {
	BinaryPath string
	Profile    string
	MaxIter    int
}

// NewClient creates sc-agent-cli client with configuration
func NewClient() *Client {
	return &Client{
		BinaryPath: getEnv("SC_AGENT_PATH", "scc"),
		Profile:    getEnv("SC_PROFILE", "qwen3.6"),
		MaxIter:    50, // Allow agent loops within generation
	}
}

// GenerateCode executes code generation via sc-agent-cli
func (c *Client) GenerateCode(prompt string) (string, error) {
	cmd := exec.Command(c.BinaryPath, "-yq", prompt)
	cmd.Env = append(os.Environ(),
		"NO_COLOR=1", // Disable ANSI escape codes for clean JSON parsing
		fmt.Sprintf("SC_MAX_ITERATIONS=%d", c.MaxIter),
		fmt.Sprintf("SC_PROFILE=%s", c.Profile),
	)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("sc-agent execution failed: %w\nStderr: %s", err, stderr.String())
	}

	output := stdout.String()
	if output == "" {
		return "", fmt.Errorf("sc-agent returned empty output")
	}

	return output, nil
}

// ReviewCode executes quality review via sc-agent-cli
func (c *Client) ReviewCode(code string) (string, error) {
	prompt := buildReviewPrompt(code)
	return c.GenerateCode(prompt)
}

// buildReviewPrompt creates quality assessment prompt
func buildReviewPrompt(code string) string {
	return fmt.Sprintf(`Review this code and rate 0-10 on these dimensions:

1. Correctness: Does it solve the stated problem correctly?
2. Completeness: Are all requirements addressed?
3. Code Quality: Is it clean, readable, and maintainable?
4. Error Handling: Does it handle errors and edge cases properly?
5. Testing: Does it include tests covering main paths?

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "correctness": 8.5,
  "completeness": 9.0,
  "code_quality": 7.5,
  "error_handling": 8.0,
  "testing": 6.0,
  "issues": ["Missing tests for edge case X", "Error handling incomplete in function Y"]
}

Code to review:
%s`, code)
}

// BuildImplementationPrompt creates initial code generation prompt
func BuildImplementationPrompt(issueNumber int, issueBody string, criteria []string) string {
	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("Implement solution for issue #%d.\n\n", issueNumber))
	sb.WriteString("Requirements:\n")
	sb.WriteString(issueBody)
	sb.WriteString("\n\nAcceptance Criteria:\n")

	for i, c := range criteria {
		sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, c))
	}

	sb.WriteString("\nGenerate production-ready code that:\n")
	sb.WriteString("- Solves the problem completely\n")
	sb.WriteString("- Includes proper error handling\n")
	sb.WriteString("- Has tests for main paths\n")
	sb.WriteString("- Is clean and maintainable\n")

	return sb.String()
}

// BuildFeedbackPrompt creates re-prompting prompt with quality feedback
func BuildFeedbackPrompt(issueNumber int, issueBody string, criteria []string,
	prevCode string, score float64, issues []string) string {

	var sb strings.Builder

	sb.WriteString(fmt.Sprintf("Improve previous implementation for issue #%d.\n\n", issueNumber))
	sb.WriteString(fmt.Sprintf("Previous attempt scored %.1f/10 with these issues:\n", score))

	for _, issue := range issues {
		sb.WriteString(fmt.Sprintf("- %s\n", issue))
	}

	sb.WriteString("\nOriginal requirements:\n")
	sb.WriteString(issueBody)
	sb.WriteString("\n\nAcceptance Criteria:\n")

	for i, c := range criteria {
		sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, c))
	}

	sb.WriteString("\nPrevious code:\n")
	sb.WriteString(prevCode)
	sb.WriteString("\n\nGenerate improved version addressing ALL issues above.\n")
	sb.WriteString("Focus on:\n")

	for _, issue := range issues {
		sb.WriteString(fmt.Sprintf("- Fixing: %s\n", issue))
	}

	return sb.String()
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
