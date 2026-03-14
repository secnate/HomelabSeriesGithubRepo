##########################################################
#
# Terraform Code From Step #1: Initial File Setup
#
##########################################################
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
}

provider "aws" {
    alias = "Disaster_Recovery_Region"
    region = var.dr_region
}
##########################################################
#
# Terraform Code From Step #2: Create Primary S3 Bucket
#
##########################################################
#
# Creating The Primary S3 Bucket
resource "aws_s3_bucket" "primary" {
  bucket = var.primary_bucket_name
}
# Bucket Versioning Is Enabled
# This Neeeded To Be Done Because "Object Lock works only in buckets that have S3 Versioning enabled" 
# Per https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}
# Bucket Server Side Encryption Tells AWS To Automatically Encrypt
# Every Object Stored In The Bucket At Rest Using The AES-256
# Relevant Documentation Page: https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
# Block all public access to this bucket
#
# Per AWS Documentation: 
#
#   "By default, new buckets, access points, and objects don't allow public access.
#    However, users can modify bucket policies, access point policies, or object 
#    permissions to allow public access. S3 Block Public Access settings override
#    these policies and permissions so that you can limit public access to these resources."
#
#    https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
##########################################################
#
# Terraform Code From Step #3: S3 Object Lock
#
##########################################################
resource "aws_s3_bucket_object_lock_configuration" "primary_bucket_object_lock" {
  bucket = aws_s3_bucket.primary.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary]
}
##########################################################
#
# Terraform Code From Step #4: Creating DR Bucket In Second Region
#
##########################################################
# # Creating The Secondary S3 Bucket
resource "aws_s3_bucket" "secondary" {
    provider = aws.Disaster_Recovery_Region
    bucket = var.secondary_bucket_name
}
# Bucket Versioning Is Enabled
# This Neeeded To Be Done Because "Object Lock works only in buckets that have S3 Versioning enabled" 
# Per https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html
resource "aws_s3_bucket_versioning" "secondary" {
    provider = aws.Disaster_Recovery_Region
    bucket = aws_s3_bucket.secondary.id

    versioning_configuration {
        status = "Enabled"
    }
}
################################################################################################################

resource "aws_s3_bucket_object_lock_configuration" "secondary_bucket_object_lock" {
  provider = aws.Disaster_Recovery_Region
  
  bucket = aws_s3_bucket.secondary.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.secondary]
}

################################################################################################################

# Bucket Server Side Encryption Tells AWS To Automatically Encrypt
# Every Object Stored In The Bucket At Rest Using The AES-256
# Relevant Documentation Page: https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html
resource "aws_s3_bucket_server_side_encryption_configuration" "secondary" {
    provider = aws.Disaster_Recovery_Region
    bucket = aws_s3_bucket.secondary.bucket

    rule {
        apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
    }
  }
}
# Block all public access to this bucket
#
# Per AWS Documentation: 
#
#   "By default, new buckets, access points, and objects don't allow public access.
#    However, users can modify bucket policies, access point policies, or object 
#    permissions to allow public access. S3 Block Public Access settings override
#    these policies and permissions so that you can limit public access to these resources."
#
#    https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html
resource "aws_s3_bucket_public_access_block" "secondary" {
    provider = aws.Disaster_Recovery_Region
    bucket = aws_s3_bucket.secondary.id

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}
##########################################################
#
# Terraform Code From Step #5: Cross-Region Replication
#
##########################################################
#
# Preparation For The Final Replication Rule
#
##########################################################

# IAM role for replication
resource "aws_iam_role" "replication" {
    name     = "s3-replication-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {
                Service = "s3.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }]
    })
}

# IAM policy granting replication permissions to the buckets
resource "aws_iam_role_policy" "replication" {
  name     = "s3-replication-policy"
  role     = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}
##########################################################
# The replication rule itself — tells S3 to copy everything
# from the primary bucket into the DR bucket using the role above.
# depends_on both versioning resources because replication requires
# versioning to be active on both buckets before it can be configured
resource "aws_s3_bucket_replication_configuration" "primary_to_dr" {
    # Must have bucket versioning enabled first
    depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.secondary]

    bucket = aws_s3_bucket.primary.id
    role   = aws_iam_role.replication.arn

    rule {
        id = "replicate-all"
        status = "Enabled"

        destination {
            bucket = aws_s3_bucket.secondary.arn
            storage_class = "STANDARD"
        }
    }
}
##########################################################
#
# Terraform Code From Step #7: Dedicated Account For Restic Backups
#
##########################################################
resource "aws_iam_user" "restic_backup" {
    name = "restic-backup-agent"
}

resource "aws_iam_access_key" "restic_backup" {
    user = aws_iam_user.restic_backup.name
}

data "aws_iam_policy_document" "restic_backup_policy" {
    statement {
        effect    = "Allow"
        actions   = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
        ]
        resources = [
            aws_s3_bucket.primary.arn,
            "${aws_s3_bucket.primary.arn}/*"
        ]
    }
}

resource "aws_iam_user_policy" "restic_backup" {
    name   = "restic-s3-least-privilege"
    user   = aws_iam_user.restic_backup.name
    policy = data.aws_iam_policy_document.restic_backup_policy.json
}