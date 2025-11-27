# =========================================
# AUTO-DETECT DEFAULT VPC & SUBNETS
# =========================================

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# =========================================
# SECURITY GROUP FOR REDSHIFT
# =========================================

resource "aws_security_group" "redshift_sg" {
  name        = "${var.project_name}-redshift-sg"
  description = "Security group for Redshift Serverless"
  vpc_id      = data.aws_vpc.default.id

  # Inbound: PostgreSQL (5439) from VPC
  ingress {
    description = "Redshift access from VPC"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    self = true
  }

  # Outbound: All traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Redshift Security Group"
  }
}

# =========================================
# IAM ROLE FOR REDSHIFT (S3 Access)
# =========================================

resource "aws_iam_role" "redshift_s3_role" {
  name = "${var.project_name}-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "redshift.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "Redshift S3 Access Role"
  }
}

resource "aws_iam_role_policy" "redshift_s3_policy" {
  name = "${var.project_name}-redshift-s3-policy"
  role = aws_iam_role.redshift_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.medical_data.arn,
          "${aws_s3_bucket.medical_data.arn}/*"
        ]
      },
      {
        Sid    = "GlueAccessForParquet"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetTableVersion",
          "glue:GetTableVersions",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = "*"
      }
    ]
  })
}

# =========================================
# REDSHIFT SERVERLESS NAMESPACE
# =========================================

resource "aws_redshiftserverless_namespace" "medical_namespace" {
  namespace_name = "${var.project_name}-namespace"

  admin_username      = var.redshift_admin_username
  admin_user_password = var.redshift_admin_password
  db_name             = var.redshift_database_name

  iam_roles = [
    aws_iam_role.redshift_s3_role.arn
  ]

  tags = {
    Name = "Medical Data Warehouse Namespace"
  }
}

# =========================================
# REDSHIFT SERVERLESS WORKGROUP
# =========================================

resource "aws_redshiftserverless_workgroup" "medical_workgroup" {
  namespace_name = aws_redshiftserverless_namespace.medical_namespace.namespace_name
  workgroup_name = "${var.project_name}-workgroup"

  base_capacity = var.redshift_base_capacity

  publicly_accessible = false
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.redshift_sg.id]

  tags = {
    Name = "Medical Data Warehouse Workgroup"
  }

  depends_on = [
    aws_redshiftserverless_namespace.medical_namespace
  ]
}