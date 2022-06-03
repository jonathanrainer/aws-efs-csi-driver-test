resource "kubernetes_deployment" "root_access_deployment" {
  metadata {
    name = "test-ops"
    namespace = var.namespace
    labels = {
      app = "operations"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "operations"
      }
    }
    template {
      metadata {
        labels = {
          app = "operations"
        }
      }
      spec {
        container {
          name = "app"
          image = "busybox"
          command = ["/bin/sh", "-c", "while true; do sleep 86400; done"]
          volume_mount {
            mount_path = "/efs"
            name       = kubernetes_persistent_volume_claim.efs_root.metadata[0].name
          }
        }
        volume {
          name = kubernetes_persistent_volume_claim.efs_root.metadata[0].name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.efs_root.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume" "efs_root" {
  metadata {
    name = "efs-root"
    labels = {
      "access": "root"
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

resource "kubernetes_storage_class" "static_provisioning_storage_class" {
  storage_provisioner = "efs.csi.aws.com"
  metadata {
    name = "efs-static"
  }
}

resource "kubernetes_persistent_volume_claim" "efs_root" {
  metadata {
    name = "efs-root"
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

resource "kubernetes_storage_class" "dynamic_provisioning_storage_class" {
  storage_provisioner = "efs.csi.aws.com"
  metadata {
    name = "efs-dynamic"
  }
  mount_options = [
    "tls"
  ]
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId = aws_efs_file_system.test-file-system.id
    directoryPerms = "777"
    gidRangeStart: "1000"
    gidRangeEnd: "2000"
    basePath: "/dynamic"
    tags: "SCTag:'Look at the spaces'"
  }
}