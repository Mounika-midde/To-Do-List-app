terraform {
  required_version = "~>1.11.4"
  required_providers {
    aws ={
        source = "hashicorp/aws"
        version = "~>3.20"
    }
  }
}

provider "aws" {
 region = "ap-south-1"
 profile = "default"  
}