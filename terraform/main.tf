# Fetch current account metrics dynamically to build clean namespace scopes
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "aegisrag_key" {
  description             = "AegisRAG Master Key for Enterprise Envelope Encryption Operations"
  deletion_window_in_days = var.environment == "local" ? 7 : 30 # Max safety buffer in prod
  enable_key_rotation     = true

  # IAM Namespace Policy: Restricts key utilization explicitly to the target environment footprint
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "aegisrag-kms-namespace-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow AegisRAG Microservice Cryptographic Actions"
        Effect = "Allow"
        Principal = {
          AWS = "*" # In true prod, restrict this to your specific EKS/Kubernetes IAM Role ARN
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = var.environment
          }
        }
      }
    ]
  })

  # Enterprise Deletion Prevention Safeguard
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Application = "AegisRAG Core Gateway"
    Namespace   = "aegisrag-${var.environment}"
  }
}

# Namespace Scoped Key Alias
resource "aws_kms_alias" "aegisrag_key_alias" {
  # Dynamically prefixes the namespace path based on your deployment tier
  name          = "alias/${var.environment}/aegisrag-master-key"
  target_key_id = aws_kms_key.aegisrag_key.key_id
}

output "kms_key_arn" {
  value       = aws_kms_key.aegisrag_key.arn
  description = "Inject this ARN target signature inside Kubernetes configuration layers and backend .env files."
}

output "scoped_namespace_alias" {
  value       = aws_kms_alias.aegisrag_key_alias.name
  description = "The environment-isolated cryptographic namespace entry path handle."
}
