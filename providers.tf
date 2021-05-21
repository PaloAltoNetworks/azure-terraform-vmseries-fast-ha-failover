terraform {
  required_version = "> 0.14.0"

  required_providers {
    azurerm = {
      version = "~> 2.54"
    }
  }
}

provider "azurerm" {
  features {}
}