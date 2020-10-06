terraform {
  required_version = ">= 0.13"
  required_providers {
    ignition = {
      source  = "terraform-providers/ignition"
      version = ">= 1.2.1"
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
