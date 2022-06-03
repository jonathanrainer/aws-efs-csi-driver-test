provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = var.cluster.endpoint
  cluster_ca_certificate = base64decode(var.cluster.ca_cert)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster.name]
    command     = "aws"
  }
}