variable "region" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster (created by the root stack)."
  type        = string
  default     = "vprofile-eks-cluster"
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the shared ALB (app and Argo CD). Use [\"<your-ip>/32\"] to restrict."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_cidrs must contain at least one valid CIDR block."
  }
}

variable "helm_repo_url" {
  description = "HTTPS URL of the GitOps helm repository Argo CD deploys from."
  type        = string
  default     = "https://github.com/Tekkieware/devops-helm.git"
}

variable "helm_repo_username" {
  description = "Username for the helm repo (any non-empty value works with a GitHub token)."
  type        = string
  default     = "x-access-token"
}

variable "helm_repo_token" {
  description = "GitHub token with read access to the helm repo (fine-grained: Contents read-only)."
  type        = string
  sensitive   = true
}

variable "alb_group_name" {
  description = "ALB IngressGroup shared by the app and Argo CD (one load balancer)."
  type        = string
  default     = "vprofile"
}

variable "lbc_chart_version" {
  description = "aws-load-balancer-controller chart version (keep in sync with the IAM policy file)."
  type        = string
  default     = "3.6.0"
}

variable "argocd_chart_version" {
  description = "argo-cd chart version."
  type        = string
  default     = "10.10.5"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps chart version."
  type        = string
  default     = "2.0.7"
}
