package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type Metadata struct {
	Name           string   `json:"name"`
	Responsibility string   `json:"responsibility"`
	Consumes       []string `json:"consumes"`
	Produces       []string `json:"produces"`
}

type RouteRegistrar func(*http.ServeMux)

func Run(metadata Metadata, registrars ...RouteRegistrar) error {
	if metadata.Name == "" || metadata.Responsibility == "" {
		return errors.New("component metadata is incomplete")
	}

	address := valueOrDefault("AI_SDLC_HTTP_ADDRESS", ":8080")
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).With("component", metadata.Name)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		WriteJSON(w, http.StatusOK, map[string]string{"status": "healthy"})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		WriteJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})
	mux.HandleFunc("GET /metadata", func(w http.ResponseWriter, _ *http.Request) {
		WriteJSON(w, http.StatusOK, metadata)
	})
	for _, register := range registrars {
		if register != nil {
			register(mux)
		}
	}

	server := &http.Server{
		Addr:              address,
		Handler:           requestLog(logger, mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-stop
		logger.Info("shutdown requested")
		_ = server.Close()
	}()

	logger.Info("component started", "address", address)
	err := server.ListenAndServe()
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("serve %s: %w", metadata.Name, err)
	}
	return nil
}

func WriteJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func DecodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		WriteJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return false
	}
	return true
}

func requestLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Info("request", "method", r.Method, "path", r.URL.Path, "duration", time.Since(start))
	})
}

func valueOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
