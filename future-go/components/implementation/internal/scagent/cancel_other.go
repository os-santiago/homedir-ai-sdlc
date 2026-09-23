//go:build !linux

package scagent

import "os/exec"

// Other platforms retain CommandContext's direct-process cancellation.
func configureCancellation(cmd *exec.Cmd) {}
