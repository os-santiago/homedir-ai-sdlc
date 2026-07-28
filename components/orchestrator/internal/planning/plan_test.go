package planning

import "testing"

func samplePlan() Plan {
	return Plan{
		ID:         "plan-1",
		Repository: "os-santiago/homedir",
		Items: []WorkItem{
			{ID: "schema", IssueNumbers: []int{1}, AcceptanceCriteria: []string{"schema ready"}, Status: Pending},
			{ID: "api", IssueNumbers: []int{2}, AcceptanceCriteria: []string{"api ready"}, DependsOn: []string{"schema"}, Status: Pending},
			{ID: "ui", IssueNumbers: []int{3}, AcceptanceCriteria: []string{"ui ready"}, DependsOn: []string{"api"}, Status: Pending},
		},
	}
}

func TestReconcileReturnsOnlySatisfiedWork(t *testing.T) {
	plan, ready, err := Reconcile(samplePlan(), 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(ready) != 1 || ready[0].ID != "schema" || plan.Items[0].Status != Ready {
		t.Fatalf("plan=%#v ready=%#v", plan, ready)
	}
}

func TestReconcileUnblocksNextDependency(t *testing.T) {
	plan := samplePlan()
	plan.Items[0].Status = Completed
	_, ready, err := Reconcile(plan, 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(ready) != 1 || ready[0].ID != "api" {
		t.Fatalf("ready=%#v", ready)
	}
}

func TestValidateRejectsCycle(t *testing.T) {
	plan := samplePlan()
	plan.Items[0].DependsOn = []string{"ui"}
	if err := Validate(plan); err == nil {
		t.Fatal("expected cycle to fail")
	}
}

func TestReconcileBlocksDependentsAfterFailure(t *testing.T) {
	plan := samplePlan()
	plan.Items[0].Status = Failed
	updated, ready, err := Reconcile(plan, 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(ready) != 0 || updated.Items[1].Status != Blocked {
		t.Fatalf("plan=%#v ready=%#v", updated, ready)
	}
}
