output "alb_dns_name_command" {
  description = "Prints the shared ALB DNS name once the controller has created it (1-3 minutes after apply)."
  value       = "aws elbv2 describe-load-balancers --region ${var.region} --query \"LoadBalancers[?contains(LoadBalancerName,'${var.alb_group_name}')].DNSName\" --output text"
}

output "app_url" {
  description = "App URL on the shared ALB."
  value       = "http://<alb-dns-name>/"
}

output "argocd_url" {
  description = "Argo CD URL on the shared ALB."
  value       = "http://<alb-dns-name>/argocd"
}

output "argocd_admin_username" {
  description = "Argo CD admin user."
  value       = "admin"
}

output "argocd_admin_password" {
  description = "Argo CD admin password. Show it with: terraform output -raw argocd_admin_password"
  value       = random_password.argocd_admin.result
  sensitive   = true
}
