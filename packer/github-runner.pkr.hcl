packer {
  required_plugins {
    amazon = { version = ">= 1.2.0", source = "github.com/hashicorp/amazon" }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "runner_version" {
  type    = string
  default = "2.320.0"
}

source "amazon-ebs" "github-runner" {
  ami_name      = "github-runner-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  instance_type = "t3.medium"
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name          = "github-runner"
    RunnerVersion = var.runner_version
  }
}

build {
  sources = ["source.amazon-ebs.github-runner"]

  provisioner "shell" {
    inline = ["cloud-init status --wait"]
  }

  provisioner "shell" {
    script           = "scripts/install-runner.sh"
    environment_vars = ["RUNNER_VERSION=${var.runner_version}"]
  }

  provisioner "shell" {
    script = "scripts/install-tools.sh"
  }

  provisioner "shell" {
    inline = ["sudo apt-get clean", "sudo rm -rf /var/lib/apt/lists/* /tmp/*"]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
