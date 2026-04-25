variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type    = string
  default = "rails-app"
}

variable "github_repo" {
  type    = string
  default = "myorg/myrepo"
}
