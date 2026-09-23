package scagent

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCommandSuccess(t *testing.T) {
	path := filepath.Join(t.TempDir(), "agent")
	if err := os.WriteFile(path, []byte("#!/bin/sh\nprintf 'result'\n"), 0700); err != nil {
		t.Fatal(err)
	}
	c := &Client{BinaryPath: path}
	out, err := c.GenerateCode(context.Background(), "test")
	if err != nil || out != "result" {
		t.Fatalf("output=%q err=%v", out, err)
	}
}

func TestCancellationKillsChildWork(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "agent")
	started := filepath.Join(dir, "started")
	completed := filepath.Join(dir, "completed")
	script := "#!/bin/sh\n(sleep 1; touch '" + completed + "') &\ntouch '" + started + "'\nwait\n"
	if err := os.WriteFile(path, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	c := &Client{BinaryPath: path}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	done := make(chan error, 1)
	go func() { _, err := c.GenerateCode(ctx, "test"); done <- err }()
	deadline := time.Now().Add(3 * time.Second)
	for {
		if _, err := os.Stat(started); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("agent did not start")
		}
		time.Sleep(10 * time.Millisecond)
	}
	cancel()
	select {
	case err := <-done:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("err=%v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("cancellation did not return")
	}
	time.Sleep(1200 * time.Millisecond)
	if _, err := os.Stat(completed); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("child survived cancellation: %v", err)
	}
}
