variable "env" {}
variable "instance_type"{}
variable "zone_id" {}
variable "component"{}
variable "vault_token" {}
variable "vpc_id"{}
variable "subnets_id"{}
variable "lb_internal_facing" {
  default = null
}
variable "lb_subnets" {
  default = null
}
variable "lb_required" {
  default = false
}
variable "app_port" {
  default = null
}
variable "bastion_nodes" {}
variable "server_app_port_cidr"{
default = null
}
variable "lb_app_port_cidr" {
  default = []
}
variable certificate_arn{
  default = null
}
variable "lb_app_port" {
  default = {}
}
variable "kms_key_id" {}