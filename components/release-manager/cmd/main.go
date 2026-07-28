package main

import (
	"log"

	"github.com/os-santiago/homedir-ai-sdlc/internal/platform/service"
)

func main() {
	err := service.Run(service.Metadata{
		Name:           "release-manager",
		Responsibility: "reconcile protected gates from pull request through verified production release",
		Consumes:       []string{"PullRequestProduced.v1", "CheckRunChanged.v1", "DeploymentChanged.v1"},
		Produces:       []string{"RemediationRequested.v1", "ReleaseVerified.v1", "ReleaseFailed.v1"},
	})
	if err != nil {
		log.Fatal(err)
	}
}
