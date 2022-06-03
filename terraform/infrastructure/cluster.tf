data "aws_caller_identity" "current" {}

module "eks" {
  source = "registry.terraform.io/terraform-aws-modules/eks/aws"
  version = "18.23.0"

  cluster_name                    = var.cluster.name
  cluster_version                 = var.cluster.kubernetes_version
  cluster_endpoint_public_access  = true

  cluster_ip_family = "ipv4"

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
  }

  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
    metadata_options = {
      http_endpoint =  "disabled"
    }
  }

  eks_managed_node_groups = {
    node_group = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      create_launch_template = false
      launch_template_name   = ""
      desired_size = 3
      capacity_type  = "SPOT"
    }
  }
}
