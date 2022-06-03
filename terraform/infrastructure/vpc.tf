module "vpc" {
  source  = "registry.terraform.io/terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = var.vpc.name
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  create_egress_only_igw          = true

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
    "SubnetType" = "Public"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
    "SubnetType" = "Private"
  }

}