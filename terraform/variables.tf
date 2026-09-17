variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "icorp"
}

variable "db_username" {
  type    = string
  default = "icorpadmin"
}

variable "db_password" {
  type    = string
  default = "changeme123!"
}