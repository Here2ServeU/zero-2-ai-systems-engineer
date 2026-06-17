# modules/ec2/variables.tf
variable "ami" {}
variable "instance_type" {}
variable "key_name" {}
variable "name" { default = "zero2ai-server" }
