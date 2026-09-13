package scagent

import (
	"errors"
	"os"
	"os/exec"
	"syscall"
)

// Keep shell tools in the agent's process group so request cancellation also
// terminates their work. Processes that explicitly detach require sandbox limits.
func configureCancellation(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		err := syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		if errors.Is(err, syscall.ESRCH) {
			return os.ErrProcessDone
		}
		return err
	}
}
