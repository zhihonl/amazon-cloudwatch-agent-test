// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ec2_instance_type" {
  type    = string
  default = "t3a.medium"
}

variable "ami" {
  type    = string
  default = "cloudwatch-agent-integration-test-win-2022*"
}

variable "arc" {
  type    = string
  default = "amd64"
}

variable "cwa_github_sha" {
  type    = string
  default = ""
}

variable "s3_bucket" {
  type    = string
  default = ""
}

variable "ssh_key_name" {
  type    = string
  default = ""
}

variable "ssh_key_value" {
  type    = string
  default = ""
}

variable "test_name" {
  type    = string
  default = ""
}

variable "test_dir" {
  type    = string
  default = "../../../test/feature/windows"
}

variable "github_test_repo" {
  type    = string
  default = "https://github.com/zhihonl/amazon-cloudwatch-agent-test.git"
}

variable "github_test_repo_branch" {
  type    = string
  default = "beta-test"
}

variable "plugin_tests" {
  type    = string
  default = ""
}

variable "local_stack_host_name" {
  type    = string
  default = "localhost.localstack.cloud"
}