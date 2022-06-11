resource "kubernetes_storage_class" "dynamic_provisioning_storage_class" {
  storage_provisioner = "efs.csi.aws.com"
  metadata {
    name = "efs-dynamic"
  }
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId = aws_efs_file_system.test-file-system.id
    directoryPerms = "777"
    gidRangeStart: "1000"
    gidRangeEnd: "2000"
    basePath: "/dynamic"
    extraTags: "SCTag:'Look at the spaces'"
  }
}

resource "kubernetes_persistent_volume_claim" "efs_dynamically_provisioned" {
  metadata {
    name      = "efs-dynamically-provisioned"
    namespace = var.namespace
  }
  spec {
    access_modes = [
      "ReadWriteMany"
    ]
    storage_class_name = kubernetes_storage_class.dynamic_provisioning_storage_class.metadata[0].name
    resources {
      requests = {
        "storage" : "5Gi"
      }
    }
    selector {
      match_labels = {
        "access" : "root"
      }
    }
  }
}



resource "kubernetes_deployment" "root_access_deployment" {
  depends_on = [kubernetes_persistent_volume_claim.efs_dynamically_provisioned]
  metadata {
    name = "dynamically-provisioned-app"
    namespace = var.namespace
    labels = {
      app = "dynamic"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "dynamic"
      }
    }
    template {
      metadata {
        labels = {
          app = "dynamic"
        }
      }
      spec {
        container {
          name = "app"
          image = "busybox"
          command = ["/bin/sh", "-c", "while true; do sleep 86400; done"]
          volume_mount {
            mount_path = "/efs"
            name       = kubernetes_persistent_volume_claim.efs_dynamically_provisioned.metadata[0].name
          }
        }
        volume {
          name = kubernetes_persistent_volume_claim.efs_dynamically_provisioned.metadata[0].name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.efs_dynamically_provisioned.metadata[0].name
          }
        }
      }
    }
  }
}