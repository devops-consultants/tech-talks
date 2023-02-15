terraform {
  cloud {
    organization = "Devops-Consultants"

    workspaces {
      tags = ["techtalks:feb2023"]
    }
  }

  required_version = ">= 1.1.0"
}
