resource "aws_ecr_repository" "docker-repo" {
  name                 = "aws-efs-csi-driver/image"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository" "helm-repo" {
  name                 = "aws-efs-csi-driver"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_lifecycle_policy" "auto-deletion-policy" {
  for_each = toset([aws_ecr_repository.docker-repo.name, aws_ecr_repository.helm-repo.name])
  repository = each.key

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 7 days",
            "selection": {
                "tagStatus": "any",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}