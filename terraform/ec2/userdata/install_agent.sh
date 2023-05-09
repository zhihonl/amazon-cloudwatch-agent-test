#! /bin/bash
echo sha ${var.cwa_github_sha}
cloud-init status --wait
echo clone and install agent
git clone --branch ${var.github_test_repo_branch} ${var.github_test_repo}
cd amazon-cloudwatch-agent-test
aws s3 cp s3://${local.binary_uri}
export PATH=$PATH:/snap/bin:/usr/local/go/bin
${var.install_agent}