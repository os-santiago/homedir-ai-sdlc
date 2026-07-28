package planning

import (
	"net/http"

	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

type reconcileRequest struct {
	Plan          Plan `json:"plan"`
	MaxConcurrent int  `json:"maxConcurrent"`
}

func Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /v1/plans/reconcile", func(w http.ResponseWriter, r *http.Request) {
		var request reconcileRequest
		if !service.DecodeJSON(w, r, &request) {
			return
		}
		plan, ready, err := Reconcile(request.Plan, request.MaxConcurrent)
		if err != nil {
			service.WriteJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": err.Error()})
			return
		}
		service.WriteJSON(w, http.StatusOK, map[string]any{"plan": plan, "ready": ready})
	})
}
