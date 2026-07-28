package cycle

import (
	"net/http"

	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

type evaluateRequest struct {
	Attempt Attempt `json:"attempt"`
	Policy  Policy  `json:"policy"`
}

func Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/cycles/evaluate", func(w http.ResponseWriter, r *http.Request) {
		var request evaluateRequest
		if !service.DecodeJSON(w, r, &request) {
			return
		}
		if request.Policy.MaximumAttempts == 0 {
			request.Policy = DefaultPolicy()
		}
		decision, err := Evaluate(request.Attempt, request.Policy)
		if err != nil {
			service.WriteJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": err.Error()})
			return
		}
		service.WriteJSON(w, http.StatusOK, decision)
	})
}
