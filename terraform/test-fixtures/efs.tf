locals {
  service_account_name = "efs-dynamic-provisioning"
  tags = {
    Name = "${var.namespace}-filesystem"
  }
}

resource "aws_efs_file_system" "test-file-system" {
  encrypted = true
}

resource "aws_efs_mount_target" "mount-target" {
  for_each = toset(data.aws_subnets.subnets.ids)

  file_system_id = aws_efs_file_system.test-file-system.id
  subnet_id      = each.key
  security_groups = [var.cluster.security_group_id]
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    SubnetType = "Public"
  }
}
