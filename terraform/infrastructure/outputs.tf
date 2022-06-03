output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cluster" {
  sensitive = true
  value = {
    name = var.cluster.name
    security_group_id = module.eks.cluster_primary_security_group_id
    endpoint = module.eks.cluster_endpoint
    ca_cert = module.eks.cluster_certificate_authority_data
  }
}

output "docker_repository_url" {
  value = aws_ecr_repository.docker-repo.repository_url
}

output "helm_repository_url" {
  value = aws_ecr_repository.helm-repo.repository_url
}

output "service_account_role_arn" {
  value = module.iam_iam-role-for-service-accounts-eks.iam_role_arn
}