package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Task 3: Titan Self-Healing Kubernetes Operator
//
// Watches titan-core-banking pods. If HikariPool connection errors are detected
// continuously, the operator:
//   1. Cordons the failing PostgreSQL node
//   2. Promotes the read-replica (via annotation trigger)
//   3. Patches the Service selector to route to the new primary
//   4. Restarts affected titan-core-banking pods
// ─────────────────────────────────────────────────────────────────────────────

const (
	namespace          = "titan-banking"
	coreBankingApp     = "titan-core-banking"
	postgresApp        = "titan-postgres"
	replicaApp         = "titan-postgres-replica"
	hikariErrorPattern = "HikariPool-1 - Connection is not available"
	errorThreshold     = 5               // consecutive errors before intervention
	checkInterval      = 10 * time.Second
)

type TitanHealingReconciler struct {
	client.Client
	Scheme       *runtime.Scheme
	errorCounter map[string]int // pod name -> consecutive error count
}

func (r *TitanHealingReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Only watch titan-core-banking pods
	pod := &corev1.Pod{}
	if err := r.Get(ctx, req.NamespacedName, pod); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if pod.Labels["app"] != coreBankingApp {
		return ctrl.Result{}, nil
	}

	// Check pod logs for HikariPool errors
	errorCount := r.countHikariErrors(pod)
	podKey := pod.Name

	if errorCount > 0 {
		r.errorCounter[podKey]++
		logger.Info("HikariPool error detected", "pod", podKey, "count", r.errorCounter[podKey])
	} else {
		r.errorCounter[podKey] = 0
	}

	if r.errorCounter[podKey] >= errorThreshold {
		logger.Error(fmt.Errorf("HikariPool threshold breached"), "Initiating self-healing", "pod", podKey)
		if err := r.performFailover(ctx); err != nil {
			logger.Error(err, "Failover failed")
			return ctrl.Result{RequeueAfter: 30 * time.Second}, err
		}
		r.errorCounter[podKey] = 0
	}

	return ctrl.Result{RequeueAfter: checkInterval}, nil
}

// performFailover executes the 4-step recovery sequence
func (r *TitanHealingReconciler) performFailover(ctx context.Context) error {
	logger := log.FromContext(ctx)

	// Step 1: Find and cordon the failing PostgreSQL primary node
	if err := r.cordonPostgresNode(ctx); err != nil {
		return fmt.Errorf("cordon failed: %w", err)
	}
	logger.Info("✅ Step 1: PostgreSQL primary node cordoned")

	// Step 2: Promote read-replica by patching its annotation
	if err := r.promoteReplica(ctx); err != nil {
		return fmt.Errorf("replica promotion failed: %w", err)
	}
	logger.Info("✅ Step 2: Read-replica promoted to primary")

	// Step 3: Reroute Service selector to new primary
	if err := r.rerouteService(ctx); err != nil {
		return fmt.Errorf("service reroute failed: %w", err)
	}
	logger.Info("✅ Step 3: Service traffic rerouted to new primary")

	// Step 4: Restart titan-core-banking pods to reconnect HikariPool
	if err := r.restartCoreBankingPods(ctx); err != nil {
		return fmt.Errorf("pod restart failed: %w", err)
	}
	logger.Info("✅ Step 4: titan-core-banking pods restarted")

	return nil
}

func (r *TitanHealingReconciler) cordonPostgresNode(ctx context.Context) error {
	podList := &corev1.PodList{}
	if err := r.List(ctx, podList, client.InNamespace(namespace),
		client.MatchingLabels{"app": postgresApp, "role": "primary"}); err != nil {
		return err
	}

	for _, pod := range podList.Items {
		nodeName := pod.Spec.NodeName
		node := &corev1.Node{}
		if err := r.Get(ctx, types.NamespacedName{Name: nodeName}, node); err != nil {
			return err
		}
		patch := client.MergeFrom(node.DeepCopy())
		node.Spec.Unschedulable = true
		if err := r.Patch(ctx, node, patch); err != nil {
			return err
		}
	}
	return nil
}

func (r *TitanHealingReconciler) promoteReplica(ctx context.Context) error {
	podList := &corev1.PodList{}
	if err := r.List(ctx, podList, client.InNamespace(namespace),
		client.MatchingLabels{"app": replicaApp}); err != nil {
		return err
	}

	for _, pod := range podList.Items {
		patch := client.MergeFrom(pod.DeepCopy())
		if pod.Annotations == nil {
			pod.Annotations = make(map[string]string)
		}
		// Patroni / pg_ctl promotion trigger annotation
		pod.Annotations["titan.bank/promote-to-primary"] = "true"
		pod.Labels["role"] = "primary"
		if err := r.Patch(ctx, &pod, patch); err != nil {
			return err
		}
	}
	return nil
}

func (r *TitanHealingReconciler) rerouteService(ctx context.Context) error {
	svc := &corev1.Service{}
	if err := r.Get(ctx, types.NamespacedName{
		Name: "titan-postgres-svc", Namespace: namespace,
	}, svc); err != nil {
		return err
	}

	patch := client.MergeFrom(svc.DeepCopy())
	svc.Spec.Selector["app"] = replicaApp // point to promoted replica
	svc.Spec.Selector["role"] = "primary"
	return r.Patch(ctx, svc, patch)
}

func (r *TitanHealingReconciler) restartCoreBankingPods(ctx context.Context) error {
	podList := &corev1.PodList{}
	if err := r.List(ctx, podList, client.InNamespace(namespace),
		client.MatchingLabels{"app": coreBankingApp}); err != nil {
		return err
	}

	for _, pod := range podList.Items {
		if err := r.Delete(ctx, &pod); err != nil {
			return err
		}
	}
	return nil
}

// countHikariErrors checks pod conditions/events for HikariPool errors
// In production: integrate with Loki log API or pod event stream
func (r *TitanHealingReconciler) countHikariErrors(pod *corev1.Pod) int {
	for _, condition := range pod.Status.Conditions {
		if strings.Contains(condition.Message, hikariErrorPattern) {
			return 1
		}
	}
	return 0
}

func (r *TitanHealingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Pod{}).
		Complete(r)
}

func main() {
	ctrl.SetLogger(zap.New(zap.UseDevMode(os.Getenv("ENV") == "dev")))

	scheme := runtime.NewScheme()
	_ = corev1.AddToScheme(scheme)

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme: scheme,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create manager: %v\n", err)
		os.Exit(1)
	}

	reconciler := &TitanHealingReconciler{
		Client:       mgr.GetClient(),
		Scheme:       mgr.GetScheme(),
		errorCounter: make(map[string]int),
	}

	if err := reconciler.SetupWithManager(mgr); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to setup controller: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("🚀 Titan Self-Healing Operator started")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		fmt.Fprintf(os.Stderr, "Operator crashed: %v\n", err)
		os.Exit(1)
	}
}
