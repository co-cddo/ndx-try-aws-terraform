provider "aws" {
  region = "us-west-2"
}

# S3 bucket for remote backend
resource "aws_s3_bucket" "ndx_try_tf_state" {
  bucket = "ndx-try-tf-state"
}

resource "aws_s3_bucket_acl" "ndx_try_tf_state_acl" {
  bucket     = aws_s3_bucket.ndx_try_tf_state.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.private_storage]

}

resource "aws_kms_key" "ndx_try_tf_state_kms_key" {
  description             = "This key is used to encrypt ndx_try_tf_state bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ndx_try_tf_state_encryption" {
  bucket = aws_s3_bucket.ndx_try_tf_state.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.ndx_try_tf_state_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "ndx_try_tf_state_versioning" {
  bucket = aws_s3_bucket.ndx_try_tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "private_storage" {
  bucket = aws_s3_bucket.ndx_try_tf_state.id
  rule {
    object_ownership = "ObjectWriter"
  }
}


# Billing data for David Heath
locals {
  gds_users_account_id = "622626885786"
  billing_users = [
    "david.heath",
    "stephen.grier",
    "thomas.vaughan",
  ]
}

data "aws_iam_policy_document" "billing_role_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = formatlist(
        "arn:aws:iam::%s:user/%s@digital.cabinet-office.gov.uk",
        local.gds_users_account_id,
        local.billing_users,
      )
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values = [
        "217.196.229.77/32", # GovWifi
        "217.196.229.79/32", # Brattain
        "217.196.229.80/32", # GDS BYOD VPN
        "217.196.229.81/32", # GDS VPN
        "51.149.8.0/25",     # GDS/CO VPN
        "51.149.8.128/29",   # GDS BYOD VPN
      ]
    }
  }
}

resource "aws_iam_role" "billing" {
  name               = "billing-access"
  assume_role_policy = data.aws_iam_policy_document.billing_role_assume_role_policy.json

}

resource "aws_iam_policy" "billing_read_only" {
  name   = "billing-readonly"
  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "aws-portal:ViewAccount",
                "aws-portal:ViewBilling",
                "aws-portal:ViewPaymentMethods",
                "aws-portal:ViewUsage",
                "ce:Get*",
                "ce:List*",
                "ce:Describe*",
                "health:Describe*",
                "s3:HeadBucket",
                "s3:ListAllMyBuckets"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cur:DescribeReportDefinition"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "organizations:ListTagsForResource"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "billing_billing_read_only" {
  role       = aws_iam_role.billing.name
  policy_arn = aws_iam_policy.billing_read_only.arn
}

resource "aws_iam_role_policy_attachment" "billing_org_read_only" {
  role       = aws_iam_role.billing.name
  policy_arn = "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
}


resource "aws_iam_role_policy_attachment" "billing_console_read_only" {
  role       = aws_iam_role.billing.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}
