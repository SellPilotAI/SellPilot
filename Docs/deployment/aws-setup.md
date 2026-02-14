# AWS setup

SellPilot production runs on AWS. This document outlines the main services and how they are used. Detailed Terraform or CloudFormation is added in Phase 3.

## Services used

- **RDS (PostgreSQL):** Primary database. Multi-AZ for production. Backups and PITR enabled.
- **S3:** Media storage (product images, invoice PDFs). Buckets per environment; lifecycle rules for cost control.
- **EC2 (or ECS):** Application servers running the Django API and, if used, Celery workers. Auto Scaling Group for the API.
- **ElastiCache (Redis):** Cache and Celery broker. Cluster mode optional for higher availability.
- **CloudFront:** CDN in front of S3 and optionally the app (static assets).
- **Secrets Manager (or Parameter Store):** Database credentials, API keys, JWT secret. Not in code or env files in repo.
- **CloudWatch:** Logs and metrics. Alarms for error rate, latency, DB CPU.

## Network

- VPC with public and private subnets. API and workers in private subnets; load balancer in public. Database in private subnets, no public access.
- Security groups: LB allows 443 from internet; API allows traffic from LB only; DB allows traffic from API/workers only.

## Identity

- IAM roles for EC2/ECS tasks (no long-lived keys on instances). Roles grant minimal access to S3, Secrets Manager, and RDS (via IAM auth if used, or username/password from secrets).

## Order of operations (Phase 3)

1. Create VPC and subnets.
2. Create RDS instance and security group; store credentials in Secrets Manager.
3. Create S3 bucket and optional CloudFront distribution.
4. Create ElastiCache cluster.
5. Launch EC2/ECS with application image; configure env from Secrets Manager.
6. Configure ALB and target groups; DNS (Route 53 or external) pointing to ALB.
7. Set up CloudWatch log groups and alarms.

Detailed steps and Terraform modules are added during Phase 3 implementation.
