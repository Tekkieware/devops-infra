data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

locals {
  vpc_id            = data.aws_eks_cluster.main.vpc_config[0].vpc_id
  lbc_namespace     = "kube-system"
  lbc_sa_name       = "aws-load-balancer-controller"
  argocd_namespace  = "argocd"
  allowed_cidrs_csv = join(",", var.allowed_cidrs)
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller: turns Ingress resources into ALBs
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Permissions for the AWS Load Balancer Controller (chart ${var.lbc_chart_version})."
  policy      = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Must exist before the controller pods start: credentials are injected at pod creation.
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = var.cluster_name
  namespace       = local.lbc_namespace
  service_account = local.lbc_sa_name
  role_arn        = aws_iam_role.lbc.arn

  depends_on = [aws_iam_role_policy_attachment.lbc]
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = local.lbc_namespace

  values = [templatefile("${path.module}/values/aws-load-balancer-controller.yaml.tftpl", {
    cluster_name = var.cluster_name
    region       = var.region
    vpc_id       = local.vpc_id
    sa_name      = local.lbc_sa_name
  })]

  depends_on = [aws_eks_pod_identity_association.lbc]
}

# ---------------------------------------------------------------------------
# Argo CD: served at http://<alb>/argocd on the shared ALB
# ---------------------------------------------------------------------------

# Admin password managed by Terraform (read it with `terraform output`), so no kubectl
# access is needed. Argo CD only receives the bcrypt hash, which stays stable across applies.
resource "random_password" "argocd_admin" {
  length           = 20
  special          = true
  override_special = "-_=+!"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = local.argocd_namespace
  create_namespace = true

  values = [templatefile("${path.module}/values/argocd.yaml.tftpl", {
    alb_group_name    = var.alb_group_name
    allowed_cidrs_csv = local.allowed_cidrs_csv
    helm_repo_url     = var.helm_repo_url
  })]

  # Read access to the private GitOps repo; kept out of the values file and the plan output.
  set_sensitive = [
    {
      name  = "configs.repositories.devops-helm.username"
      value = var.helm_repo_username
    },
    {
      name  = "configs.repositories.devops-helm.password"
      value = var.helm_repo_token
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = random_password.argocd_admin.bcrypt_hash
      type  = "string"
    },
  ]

  # The controller's admission webhook must be ready before Argo CD creates its Ingress.
  depends_on = [time_sleep.lbc_cleanup]
}

# Destroy-time pauses so ALBs are removed by the controller instead of being orphaned:
#   argocd-apps uninstalled -> wait (Argo CD deletes the app and its Ingress)
#   argocd uninstalled      -> wait (controller deletes the ALB)
#   controller uninstalled
resource "time_sleep" "lbc_cleanup" {
  destroy_duration = "120s"

  depends_on = [helm_release.lbc]
}

resource "time_sleep" "app_cleanup" {
  destroy_duration = "120s"

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# GitOps hand-off: Argo CD Application for the vprofile chart
# ---------------------------------------------------------------------------
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = local.argocd_namespace

  values = [templatefile("${path.module}/values/argocd-apps.yaml.tftpl", {
    namespace     = local.argocd_namespace
    helm_repo_url = var.helm_repo_url
    allowed_cidrs = var.allowed_cidrs
  })]

  depends_on = [time_sleep.app_cleanup]
}
