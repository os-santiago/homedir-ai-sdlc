package main

import (
	"log"

	"github.com/os-santiago/homedir-ai-sdlc/components/worker/internal/cycle"
	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

func main() {
	err := service.Run(service.Metadata{
		Name:           "worker",
		Responsibility: "execute isolated agentic implementation cycles and produce reviewable pull requests",
		Consumes:       []string{"WorkItemReady.v1", "RemediationRequested.v1"},
		Produces:       []string{"PullRequestProduced.v1", "WorkItemCompleted.v1", "WorkItemFailed.v1"},
	}, cycle.Routes)
	if err != nil {
		log.Fatal(err)
	}
}
