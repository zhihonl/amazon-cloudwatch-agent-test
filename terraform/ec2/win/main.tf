// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT

module "common" {
  source = "../../common"
}

module "basic_components" {
  source = "../../basic_components"

  region = var.region
}

#####################################################################
# Generate EC2 Key Pair for log in access to EC2
#####################################################################

resource "tls_private_key" "ssh_key" {
  count     = var.ssh_key_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aws_ssh_key" {
  count      = var.ssh_key_name == "" ? 1 : 0
  key_name   = "ec2-key-pair-${module.common.testing_id}"
  public_key = tls_private_key.ssh_key[0].public_key_openssh
}

locals {
  ssh_key_name        = var.ssh_key_name != "" ? var.ssh_key_name : aws_key_pair.aws_ssh_key[0].key_name
  private_key_content = var.ssh_key_name != "" ? var.ssh_key_value : tls_private_key.ssh_key[0].private_key_pem
}


#####################################################################
# Generate EC2 Instance and execute test commands
#####################################################################

resource "aws_instance" "cwagent" {
  ami                         = data.aws_ami.latest.id
  instance_type               = var.ec2_instance_type
  key_name                    = local.ssh_key_name
  iam_instance_profile        = module.basic_components.instance_profile
  vpc_security_group_ids      = [module.basic_components.security_group]
  associate_public_ip_address = true
  get_password_data           = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "cwagent-integ-test-ec2-windows-${var.test_name}-${module.common.testing_id}"
  }
}

resource "null_resource" "integration_test" {
  depends_on = [aws_instance.cwagent]

  # Install software
  connection {
    type     = "winrm"
    user     = "Administrator"
    password = rsadecrypt(aws_instance.cwagent.password_data, local.private_key_content)
    host     = aws_instance.cwagent.public_dns
  }

  # Install agent binaries
  provisioner "remote-exec" {
    inline = [
      "aws s3 cp s3://${var.s3_bucket}/integration-test/packaging/${var.cwa_github_sha}/amazon-cloudwatch-agent.msi .",
      "start /wait msiexec /i amazon-cloudwatch-agent.msi /norestart /qb-",
    ]
  }

  # Prepare Integration Test
  provisioner "remote-exec" {
    inline = [
      "echo sha ${var.cwa_github_sha}",
      "cloud-init status --wait",
      "echo clone and install agent",
      "git clone --branch ${var.github_test_repo_branch} ${var.github_test_repo}",
      "cd amazon-cloudwatch-agent-test",
    ]
  }

    #Run sanity check and integration test
  provisioner "remote-exec" {
    inline = [
      "echo prepare environment",
      "SET LOCAL_STACK_HOST_NAME=${var.local_stack_host_name}",
      "SET AWS_REGION=${var.region}",
      "echo run integration test",
      "cd \amazon-cloudwatch-agent-test",
      "go env -w GO111MODULE=auto",
      "echo run sanity test && go test \test\sanity -p 1 -v",
      "go test ${var.test_dir} -p 1 -timeout 1h -computeType=EC2 -bucket=${var.s3_bucket} -plugins='${var.plugin_tests}' -cwaCommitSha=${var.cwa_github_sha} -v"
    ]
  }
}

data "aws_ami" "latest" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami]
  }
}
