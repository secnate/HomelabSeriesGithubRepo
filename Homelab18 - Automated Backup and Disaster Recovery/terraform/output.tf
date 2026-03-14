output "primary_bucket" {
    description = "Information Regarding the Primary S3 Bucket"
    value = aws_s3_bucket.primary.bucket 
}
output "dr_bucket" {
    description = "Information Regarding the Secondary S3 Bucket"
    value = aws_s3_bucket.secondary.bucket
}
##########################################################
#
# Terraform Code From Step #7: Dedicated Account For Restic Backups
#
# This outputted information can be used for finalizing the
# restic backup account on the to-be-backed up systems
#
##########################################################
output "iam_access_key" {
    value = aws_iam_access_key.restic_backup.id
    
    # The "sensitive = true" ensures that the value is not displayed in normal CLI output
    sensitive = true
}
output "iam_secret_key" {
    value = aws_iam_access_key.restic_backup.secret

    # The "sensitive = true" ensures that the value is not displayed in normal CLI output
    sensitive = true
}