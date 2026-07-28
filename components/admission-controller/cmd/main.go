package main

import (
	"log"

	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

func main() {
	err := service.Run(service.Metadata{
		Name:           "admission-controller",
		Responsibility: "normalize issues and produce policy-backed admission decisions",
		Consumes:       []string{"IssueAdmissionRequested.v1"},
		Produces:       []string{"IssueAdmissionDecided.v1"},
	})
	if err != nil {
		log.Fatal(err)
	}
}
