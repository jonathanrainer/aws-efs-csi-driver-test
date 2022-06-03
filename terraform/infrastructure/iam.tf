module "iam_iam-role-for-service-accounts-eks" {
  source  = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.1.0"

  role_name = "efs-dynamic-provisioning"
  max_session_duration = 43200
  role_description = "A role to allow dynamic provisioning of EFS access points by the aws-efs-csi-driver"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.namespace}:efs-csi-controller-sa",
        "${var.namespace}:efs-csi-node-sa"
      ]
    }
  }

  attach_efs_csi_policy = true
}