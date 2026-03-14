##########################################################
#
# Terraform Code From Step #1: Initial File Setup
#
##########################################################
variable "primary_region" {
    description = "Primary Region"
    type = string
    default = "us-east-1"
}

variable "dr_region" {
    description = "Disaster Recovery Region"
    type = string
    default = "us-east-2"
}
##########################################################
#
# Terraform Code From Step #2: Create Primary S3 Bucket
#
##########################################################
variable "primary_bucket_name" {
    description = "Primary Bucket Name"
    type = string
    default = "nathan-homelab-18-primary-bucket"
}
##########################################################
#
# Terraform Code From Step #3: S3 Object Lock
#
##########################################################
variable "retention_days" {
    description = "Number of Retention Days"
    type = number
    default = 30
}
##########################################################
#
# Terraform Code From Step #4: Creating DR Bucket In Second Region
#
##########################################################
variable "secondary_bucket_name" {
    description = "Secondary Bucket Name"
    type = string
    default = "nathan-homelab-18-secondary-bucket"
}