variable "cluster" {
  description = "A data bag describing attributes of the cluster"
  type = object({
    name: string,
    kubernetes_version: string
  })
}

variable "vpc" {
  description = "A data bag containing attributes for the VPC"
  type = object({
    name: string
  })
}

variable "region" {
  description = "The region within which the cluster and associated resources should be created"
  type = string
}

variable "tags" {
  description = "The set of global tags that should be applied to all resources"
  type = map(string)
}

variable "namespace" {
  description = "Test namespace to be created"
}
