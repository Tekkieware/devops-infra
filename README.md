# devops-infra

Terraform for the vProfile EKS environment (eu-north-1), in two stacks with separate state:

| Stack | Path | Creates |
|-------|------|---------|
| Cluster | `./` | VPC with public subnets only, IAM roles, EKS cluster, managed node group, Pod Identity agent, EBS CSI driver |
| Platform | `./platform` | AWS Load Balancer Controller, Argo CD, Argo CD repo access, Argo CD Application for `devops-helm` |

Both use the S3 bucket `devopsapp-terraform-state` (S3 lock file, no DynamoDB).

## Prerequisites

- Terraform >= 1.10, AWS CLI, kubectl
- AWS credentials allowed to manage VPC, IAM, EKS and EC2
- The state bucket:

  ```bash
  aws s3api create-bucket --bucket devopsapp-terraform-state --region eu-north-1 \
    --create-bucket-configuration LocationConstraint=eu-north-1
  ```

## Apply

```bash
# 1. Cluster (~15-20 min)
terraform init
terraform apply
aws eks update-kubeconfig --region eu-north-1 --name vprofile-eks-cluster

# 2. Platform (~5 min)
cd platform
cp example.tfvars terraform.tfvars   # add the GitHub token (and optionally your IP)
terraform init
terraform apply
```

Then (no kubectl needed), 1-3 minutes after the apply:

```bash
# Shared ALB DNS name (or: EC2 console > Load Balancers > k8s-vprofile-... > DNS name)
aws elbv2 describe-load-balancers --region eu-north-1 \
  --query "LoadBalancers[?contains(LoadBalancerName,'vprofile')].DNSName" --output text

terraform output -raw argocd_admin_password
```

- App: `http://<alb-dns-name>/`
- Argo CD: `http://<alb-dns-name>/argocd` (user `admin`, password from the output above)

## Destroy (platform first, then cluster)

```bash
cd platform && terraform destroy   # ~5 min: includes two 2-minute pauses so the ALB is removed
cd .. && terraform destroy
```

The pauses keep Argo CD and the load balancer controller running long enough to delete the app
and its ALB; otherwise the ALB is orphaned (still billed) and blocks the VPC deletion.
Check afterwards that nothing was left behind:

```bash
# Should print nothing
aws elbv2 describe-load-balancers --region eu-north-1 \
  --query "LoadBalancers[?contains(LoadBalancerName,'vprofile')].LoadBalancerName" --output text

# MySQL's EBS volume is not deleted with the app (Kubernetes keeps StatefulSet volumes).
# List it, then delete it with: aws ec2 delete-volume --region eu-north-1 --volume-id <id>
aws ec2 describe-volumes --region eu-north-1 \
  --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name \
  --query "Volumes[].{id:VolumeId,state:State,size:Size}" --output table
```
