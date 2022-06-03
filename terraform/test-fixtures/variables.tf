variable "region" {
  description = "The region within which the cluster and associated resources should be created"
  type = string
}

variable "tags" {
  description = "The set of global tags that should be applied to all resources"
  type = map(string)
}

variable "vpc_id" {
  description = "The VPC to provision the Mount Targets inside"
  type = string
}

variable "cluster" {
  description = "A databag that contains details of the cluster to provision resources within"
  type = object({
    name = string
    endpoint = string
    ca_cert = string
    security_group_id = string
  })
}

variable "namespace" {
  description = "The namespace within which to run the tests"
  type = string
}
