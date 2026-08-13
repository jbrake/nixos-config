{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Local clusters and day-to-day Kubernetes operations.
    kind
    kubectl
    kubectl-tree
    kubectx
    k9s
    stern

    # Manifest authoring, packaging, rendering, and validation.
    kubernetes-helm
    kustomize
    yq-go
    kubeconform
    kube-linter

    # GitOps and progressive delivery clients. The controllers themselves are
    # installed into Kubernetes later; these packages only provide local CLIs.
    argocd
    argo-rollouts

    # Local secret-encryption and repository/image scanning exercises.
    age
    sops
    kubeseal
    gitleaks
    trivy

    # Optional EKS comparison exercises. Merely installing these clients does
    # not create AWS resources or authenticate to an AWS account.
    awscli2
    eksctl
  ];
}
