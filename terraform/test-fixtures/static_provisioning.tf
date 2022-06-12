resource "kubernetes_storage_class" "static_provisioning_storage_class" {
  storage_provisioner = "efs.csi.aws.com"
  metadata {
    name = "efs-static"
    labels = {
      provisioning-type: "static"
    }
  }
}

resource "kubernetes_persistent_volume" "efs_statically_provisioned" {
  metadata {
    name = "efs-statically-provisioned"
    labels = {
      provisioning-type: "static"
    }
  }
  spec {
    storage_class_name = kubernetes_storage_class.static_provisioning_storage_class.metadata[0].name
    access_modes = [
      "ReadWriteMany"
    ]
    capacity     = {
      storage = "5Gi"
    }
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.test_file_system.id
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "efs_statically_provisioned" {
  depends_on = [aws_efs_mount_target.mount_target]
  metadata {
    name = "efs-statically-provisioned"
    namespace = var.namespace
    labels = {
      provisioning-type: "static"
    }
  }
  spec {
    access_modes = [
      "ReadWriteMany"
    ]
    storage_class_name = kubernetes_storage_class.static_provisioning_storage_class.metadata[0].name
    resources {
      requests = {
        "storage": "5Gi"
      }
    }
    selector {
      match_labels = {
        provisioning-type: "static"
      }
    }
  }
}

resource "kubernetes_deployment" "statically_provisioned_app" {
  depends_on = [kubernetes_persistent_volume_claim.efs_statically_provisioned]
  metadata {
    name = "statically-provisioned-app"
    namespace = var.namespace
    labels = {
      app = "stasis"
      provisioning-type: "static"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "stasis"
      }
    }
    template {
      metadata {
        labels = {
          app = "stasis"
          provisioning-type: "static"
        }
      }
      spec {
        container {
          name = "app"
          image = "busybox"
          command = ["/bin/sh", "-c", "while true; do sleep 86400; done"]
          volume_mount {
            mount_path = "/efs"
            name       = kubernetes_persistent_volume_claim.efs_statically_provisioned.metadata[0].name
          }
        }
        volume {
          name = kubernetes_persistent_volume_claim.efs_statically_provisioned.metadata[0].name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.efs_statically_provisioned.metadata[0].name
          }
        }
      }
    }
  }
}