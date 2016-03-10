variable "aws_region" {
    description = "AWS region to launch servers."
    default = "us-east-1"
}

variable "aws_amis" {
    default = {
        "us-east-1" = "ami-7ba59311"
    }
}

variable "key_name" {
}

variable "public_key_path" {
}
