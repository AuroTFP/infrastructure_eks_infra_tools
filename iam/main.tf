terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.24.0"
    }
  }

}
provider "aws" {
  region = "us-east-1"
}

# Thanos metrics are shipped to this s3 bucket every 2hs
resource "aws_s3_bucket" "metrics" {
  bucket = "dev-demo-thanos-metrics-prometheus"

  tags = {
    environment = "dev"
  }
}

resource "aws_s3_bucket_acl" "metrics_acl" {
  bucket = aws_s3_bucket.metrics.id
  acl    = "private"
}

# IAM policy
resource "aws_iam_policy" "thanos_metrics_policy" {
  name = "thanos_role_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.metrics.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.metrics.bucket}"
        ]
      },
      {
        Effect =  "Allow",
        Action =  [
        "ec2:AttachVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications",
        "ec2:DetachVolume",
        "ec2:ModifyVolume"
        ],
        Resource=  "*"
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ChangeResourceRecordSets"
          ],
          Resource = [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ],
          Resource = [
            "*"
          ]
        }
    ]
  })
}

# Observer cluster role
resource "aws_iam_role" "thanos_role" {
  name = "thanos-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          # oidc configuration provided by the eks cluster
          Federated = "arn:aws:iam::770688751007:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A25A138B04884A7216DFDB5B6492E79C"
        }
        Condition = {
          StringLike = {
            "oidc.eks.us-east-1.amazonaws.com/id/A25A138B04884A7216DFDB5B6492E79C:sub" : "system:serviceaccount:monitoring:thanos-role"
            "oidc.eks.us-east-1.amazonaws.com/id/A25A138B04884A7216DFDB5B6492E79C:aud": "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = {
    environment = "dev"
  }
}
resource "aws_iam_role_policy_attachment" "thanos_attach" {
  role       = aws_iam_role.thanos_role.name
  policy_arn = aws_iam_policy.thanos_metrics_policy.arn
}

# Client clusters roles
resource "aws_iam_role" "thanos_infra_tools_role" {
  name = "thanos-infra-tools-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          # oidc configuration provided by the eks cluster
          Federated = "arn:aws:iam::770688751007:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/E5D083C3F6424102B2DC5B2355E03DCE"
        }
        Condition = {
          StringLike = {
            "oidc.eks.us-east-1.amazonaws.com/id/E5D083C3F6424102B2DC5B2355E03DCE:sub" : "system:serviceaccount:monitoring:thanos-role"
            "oidc.eks.us-east-1.amazonaws.com/id/E5D083C3F6424102B2DC5B2355E03DCE:aud": "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = {
    environment = "infra"
  }
}


resource "aws_iam_role_policy_attachment" "role_attach" {
  role       = aws_iam_role.thanos_infra_tools_role.name
  policy_arn = aws_iam_policy.thanos_metrics_policy.arn
}



