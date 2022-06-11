resource "kubernetes_storage_class" "static_provisioning_storage_class" {
  storage_provisioner = "efs.csi.aws.com"
  metadata {
    name = "efs-static"
    labels = {
      "provisioning-type": "static"
    }
  }
}

resource "kubernetes_persistent_volume" "efs_statically_provisioned" {
  metadata {
    name = "efs-statically-provisioned"
    labels = {
      "provisioning-type": "static"
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
        volume_handle = aws_efs_file_system.test-file-system.id
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "efs_statically_provisioned" {
  depends_on = [kubernetes_persistent_volume.efs_statically_provisioned]
  metadata {
    name = "efs-statically-provisioned"
    namespace = var.namespace
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
        "access": "root"
      }
    }
  }
}

resource "kubernetes_deployment" "root_access_deployment" {
  depends_on = [kubernetes_persistent_volume_claim.efs_statically_provisioned]
  metadata {
    name = "statically-provisioned-app"
    namespace = var.namespace
    labels = {
      app = "static"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "static"
      }
    }
    template {
      metadata {
        labels = {
          app = "static"
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