package admission

import (
	"net/http"

	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

type evaluateRequest struct {
	Issue  Issue  `json:"issue"`
	Policy Policy `json:"policy"`
}

func Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/admissions/evaluate", func(w http.ResponseWriter, r *http.Request) {
		var request evaluateRequest
		if !service.DecodeJSON(w, r, &request) {
			return
		}
		if request.Policy.Version == "" {
			request.Policy = DefaultPolicy()
		}
		service.WriteJSON(w, http.StatusOK, Evaluate(request.Issue, request.Policy))
	})
}
