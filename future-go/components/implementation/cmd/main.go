package main

import (
	"log"
	"net/http"
	"os"

	"github.com/os-santiago/homedir-ai-sdlc/components/implementation/internal/implementation"
)

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds)
	log.Println("[main] Starting Implementation Service")

	// Configuration
	port := getEnv("PORT", "8082")
	scProfile := getEnv("SC_PROFILE", "qwen3.6")
	maxIter := getEnv("MAX_IMPLEMENTATION_ITERATIONS", "3")
	threshold := getEnv("QUALITY_THRESHOLD", "8.0")

	log.Printf("[config] PORT=%s", port)
	log.Printf("[config] SC_PROFILE=%s", scProfile)
	log.Printf("[config] MAX_IMPLEMENTATION_ITERATIONS=%s", maxIter)
	log.Printf("[config] QUALITY_THRESHOLD=%s", threshold)

	// Create HTTP handler
	handler := implementation.NewHandler()

	// Start server
	addr := ":" + port
	log.Printf("[main] Listening on %s", addr)
	log.Printf("[main] Endpoints:")
	log.Printf("[main]   POST /api/implementation/generate - Generate code with iterations")
	log.Printf("[main]   GET  /health - Health check")

	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("[main] Server failed: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
