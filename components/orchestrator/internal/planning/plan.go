package planning

import (
	"errors"
	"fmt"
	"sort"
)

type Status string

const (
	Pending   Status = "pending"
	Ready     Status = "ready"
	Running   Status = "running"
	Completed Status = "completed"
	Failed    Status = "failed"
	Blocked   Status = "blocked"
)

type WorkItem struct {
	ID                 string   `json:"id"`
	IssueNumbers       []int    `json:"issueNumbers"`
	AcceptanceCriteria []string `json:"acceptanceCriteria"`
	DependsOn          []string `json:"dependsOn"`
	Status             Status   `json:"status"`
}

type Plan struct {
	ID         string     `json:"id"`
	Repository string     `json:"repository"`
	Items      []WorkItem `json:"items"`
}

func Validate(plan Plan) error {
	if plan.ID == "" || plan.Repository == "" || len(plan.Items) == 0 {
		return errors.New("plan id, repository and at least one work item are required")
	}
	items := make(map[string]WorkItem, len(plan.Items))
	for _, item := range plan.Items {
		if item.ID == "" || len(item.IssueNumbers) == 0 || len(item.AcceptanceCriteria) == 0 {
			return fmt.Errorf("work item %q is incomplete", item.ID)
		}
		if _, exists := items[item.ID]; exists {
			return fmt.Errorf("duplicate work item %q", item.ID)
		}
		items[item.ID] = item
	}
	for _, item := range plan.Items {
		for _, dependency := range item.DependsOn {
			if dependency == item.ID {
				return fmt.Errorf("work item %q depends on itself", item.ID)
			}
			if _, exists := items[dependency]; !exists {
				return fmt.Errorf("work item %q has unknown dependency %q", item.ID, dependency)
			}
		}
	}
	if hasCycle(items) {
		return errors.New("work item dependency graph contains a cycle")
	}
	return nil
}

func Reconcile(plan Plan, maxConcurrent int) (Plan, []WorkItem, error) {
	if err := Validate(plan); err != nil {
		return plan, nil, err
	}
	if maxConcurrent < 1 {
		return plan, nil, errors.New("maxConcurrent must be positive")
	}

	status := make(map[string]Status, len(plan.Items))
	running := 0
	for _, item := range plan.Items {
		status[item.ID] = item.Status
		if item.Status == Running {
			running++
		}
	}

	available := maxConcurrent - running
	if available < 0 {
		available = 0
	}
	ready := make([]WorkItem, 0)
	for index := range plan.Items {
		item := &plan.Items[index]
		if item.Status != Pending && item.Status != Ready {
			continue
		}
		dependenciesComplete := true
		dependencyFailed := false
		for _, dependency := range item.DependsOn {
			switch status[dependency] {
			case Completed:
			case Failed, Blocked:
				dependencyFailed = true
			default:
				dependenciesComplete = false
			}
		}
		if dependencyFailed {
			item.Status = Blocked
			continue
		}
		if dependenciesComplete {
			item.Status = Ready
			ready = append(ready, *item)
		}
	}

	sort.Slice(ready, func(i, j int) bool { return ready[i].ID < ready[j].ID })
	if len(ready) > available {
		ready = ready[:available]
	}
	return plan, ready, nil
}

func hasCycle(items map[string]WorkItem) bool {
	const (
		unseen = iota
		visiting
		visited
	)
	state := make(map[string]int, len(items))
	var visit func(string) bool
	visit = func(id string) bool {
		if state[id] == visiting {
			return true
		}
		if state[id] == visited {
			return false
		}
		state[id] = visiting
		for _, dependency := range items[id].DependsOn {
			if visit(dependency) {
				return true
			}
		}
		state[id] = visited
		return false
	}
	for id := range items {
		if state[id] == unseen && visit(id) {
			return true
		}
	}
	return false
}
