package implementation

import (
	"encoding/json"
	"log"
	"net/http"
)

// Handler provides HTTP API for implementation service
type Handler struct {
	iterator *Iterator
}

// NewHandler creates HTTP handler
func NewHandler() *Handler {
	return &Handler{
		iterator: NewIterator(),
	}
}

// ServeHTTP routes requests
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/api/implementation/generate":
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		h.handleGenerate(w, r)
	case "/health":
		h.handleHealth(w, r)
	default:
		http.NotFound(w, r)
	}
}

// handleGenerate processes code generation request
func (h *Handler) handleGenerate(w http.ResponseWriter, r *http.Request) {
	var req GenerateRequest

	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(&req); err != nil {
		log.Printf("[http] Invalid request: %v", err)
		writeError(w, http.StatusBadRequest, "Invalid request body: "+err.Error())
		return
	}

	// Validate request
	if req.IssueNumber <= 0 {
		writeError(w, http.StatusBadRequest, "issue_number must be positive")
		return
	}
	if req.IssueBody == "" {
		writeError(w, http.StatusBadRequest, "issue_body is required")
		return
	}

	log.Printf("[http] Received generation request for issue #%d", req.IssueNumber)

	// Execute generation
	resp, err := h.iterator.Generate(req)
	if err != nil {
		log.Printf("[http] Generation failed: %v", err)
		writeError(w, http.StatusInternalServerError, "Generation failed: "+err.Error())
		return
	}

	log.Printf("[http] Generation completed: score=%.1f, iterations=%d, selected=%d",
		resp.QualityScore, resp.IterationsUsed, resp.SelectedAttempt)

	writeJSON(w, http.StatusOK, resp)
}

// handleHealth returns service health status
func (h *Handler) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"service": "implementation",
	})
}

// writeJSON writes JSON response
func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")

	if err := encoder.Encode(data); err != nil {
		log.Printf("[http] Failed to encode response: %v", err)
	}
}

// writeError writes error response
func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{
		"error": message,
	})
}
