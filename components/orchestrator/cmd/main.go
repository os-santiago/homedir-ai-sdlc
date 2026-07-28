package main

import (
	"log"

	"github.com/os-santiago/homedir-ai-sdlc/components/orchestrator/internal/planning"
	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

func main() {
	err := service.Run(service.Metadata{
		Name:           "orchestrator",
		Responsibility: "decompose accepted work and coordinate dependency-aware delivery sagas",
		Consumes:       []string{"IssueAdmissionDecided.v1", "WorkItemCompleted.v1", "WorkItemFailed.v1"},
		Produces:       []string{"WorkPlanCreated.v1", "WorkItemReady.v1", "SagaCompensationRequested.v1"},
	}, planning.Routes)
	if err != nil {
		log.Fatal(err)
	}
}
