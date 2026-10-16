# Copy to terraform.tfvars (git-ignored) and fill in.

# GitHub fine-grained token: repository access = devops-helm only, Contents = Read-only.
helm_repo_token = "github_pat_..."

# Restrict the ALB (app + Argo CD) to your public IP; default is open to everyone.
# allowed_cidrs = ["203.0.113.10/32"]
