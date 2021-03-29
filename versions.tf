terraform {
  required_version = ">= 0.13"
  required_providers {
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "< 2.0.0"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
