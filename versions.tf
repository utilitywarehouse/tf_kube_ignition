terraform {
  required_version = ">= 0.13"
  required_providers {
    ignition = {
      source = "terraform-providers/ignition"
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
