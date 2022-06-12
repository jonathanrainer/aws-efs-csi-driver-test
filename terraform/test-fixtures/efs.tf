locals {
  service_account_name = "efs-dynamic-provisioning"
}

resource "aws_efs_file_system" "test_file_system" {
  encrypted = true
  tags = {
    Name = "${var.namespace}-filesystem"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  for_each = toset(data.aws_subnets.subnets.ids)

  file_system_id = aws_efs_file_system.test_file_system.id
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
