package main

import (
	"log"

	"github.com/os-santiago/homedir-ai-sdlc/components/admission-controller/internal/admission"
	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

func main() {
	err := service.Run(service.Metadata{
		Name:           "admission-controller",
		Responsibility: "normalize issues and produce policy-backed admission decisions",
		Consumes:       []string{"IssueAdmissionRequested.v1"},
		Produces:       []string{"IssueAdmissionDecided.v1"},
	}, admission.Routes)
	if err != nil {
		log.Fatal(err)
	}
}
