# mCloud Network Terraform

A modular Terraform project that creates the VPC, subnets, routing, and security groups for the mCloud migration POC. It is intentionally small and simple for the POC, but structured so it can be extended to a production deployment.

## Repository layout

```text
terraform/
├── main.tf                  # Wires the modules together
├── variables.tf             # Root variables
├── terraform.tfvars         # POC-specific values
├── providers.tf             # AWS provider and required version
├── backend.tf               # Local state for POC (S3 template commented)
├── outputs.tf               # Resource IDs to use in EC2/RDS/ALB creation
├── README.md
├── .gitignore
└── modules/
    ├── vpc/
    ├── igw/                 # Internet gateway
    ├── subnets/             # Public and private subnets
    ├── nat/                 # NAT gateways and Elastic IPs
    ├── routing/             # Route tables and associations
    └── security_groups/     # ALB, Windows EC2, and RDS security groups
```

## What it creates

- **VPC** `mcloud-poc-vpc` (`10.0.0.0/16`) with DNS hostnames and DNS support enabled.
- **Internet Gateway** attached to the VPC.
- **Public subnets** in `ap-south-1a` and `ap-south-1b` with auto-assign public IP enabled (for NAT gateways and future ALB).
- **Private subnets** in `ap-south-1a` and `ap-south-1b` for EC2 and RDS.
- **NAT Gateway**: one Elastic IP and one NAT gateway in the first public subnet for the POC.
- **Route tables**:
  - Public route table sends `0.0.0.0/0` to the Internet Gateway.
  - Private route table sends `0.0.0.0/0` to the NAT gateway.
- **Security groups**:
  - `mcloud-poc-alb-sg`: allows 80/443 from the internet.
  - `mcloud-poc-windows-sg`: allows 80/443 from the ALB SG, optionally 80/443 + 3389 from `admin_cidr_blocks`, and optionally 9040 from `device_cidr_blocks`.
  - `mcloud-poc-rds-sg`: allows 1433 from the Windows EC2 security group only.

## How to use

1. Install Terraform and authenticate to AWS (environment variables or `~/.aws/credentials`).
2. Update `terraform.tfvars`:
   - Change `admin_cidr_blocks` to your public IP if you want direct RDP or HTTP/HTTPS access to the EC2.
   - Change `device_cidr_blocks` if you test legacy devices on port 9040.
3. Run:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

4. After apply, Terraform prints the VPC, subnet, and security group IDs. Use these in the next steps when you create:
   - the RDS SQL Server instance (`mcloud-poc-rds-sg`)
   - the Windows EC2 instance (`mcloud-poc-windows-sg` and a public subnet)
   - the Application Load Balancer (`mcloud-poc-alb-sg` and public subnets)

## Configuration created by default (`terraform.tfvars`)

```hcl
region      = "ap-south-1"
project     = "mcloud"
environment = "poc"
vpc_cidr    = "10.0.0.0/16"

azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

enable_nat_gateway = true
single_nat_gateway = true
```

## What to change for production

When the actual project starts, the following changes are typically made:

### 1. Remote state

Uncomment and configure `backend.tf` to use an S3 backend with DynamoDB locking. Example:

```hcl
terraform {
  backend "s3" {
    bucket         = "mcloud-terraform-state-prod"
    key            = "network/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "mcloud-terraform-locks"
    encrypt        = true
  }
}
```

### 2. Environment and high availability

In `terraform.tfvars`:

```hcl
environment        = "prod"
single_nat_gateway = false
admin_cidr_blocks  = []
device_cidr_blocks = []
```

- `single_nat_gateway = false` creates one NAT gateway per AZ for high availability.
- `admin_cidr_blocks = []` removes direct RDP/HTTP/HTTPS access. Use AWS Systems Manager Session Manager or a bastion host instead.
- `device_cidr_blocks` should be populated only with known customer/device network ranges; current-generation devices use HTTPS/443 and do not need port 9040.

### 3. Security groups

- Restrict the **ALB security group** to known office, VPN, or WAF IPs. Consider adding AWS WAF in front of the ALB.
- Remove direct `admin_cidr_blocks` access from the **Windows EC2 security group** so it accepts traffic only from the ALB SG.
- Add VPC Flow Logs, AWS Network Firewall, or AWS Shield Advanced as required.

### 4. Subnet placement

- Place the **Windows EC2** and **RDS SQL Server** in the **private subnets**.
- Keep only the **ALB** and **NAT gateways** in the public subnets.
- Use an Application Load Balancer in the public subnets to terminate HTTPS and forward to the EC2 in the private subnets.

### 5. Database tier

- Move RDS SQL Server to a Multi-AZ deployment.
- Use SQL Server Standard or Enterprise edition with appropriate instance sizing (`db.t3.large` or bigger).
- Store the database password in AWS Secrets Manager and reference it from Parameter Store, not hardcoded in `appsettings.json`.

### 6. Additional production considerations

- Add `environments/` folders (`poc/`, `dev/`, `prod/`) or separate Terraform workspaces.
- Use a CI/CD pipeline (GitHub Actions, GitLab CI, Azure DevOps) to run `terraform plan` and `terraform apply`.
- Enable AWS Config, Security Hub, and CloudTrail.
- Enable EBS encryption and S3 bucket access logging.
- Add CloudWatch alarms for NAT gateway, VPC, and security group traffic anomalies.
- Consider AWS Transit Gateway or VPC peering if the mCloud deployment needs to connect to on-premise networks or other VPCs.

## Outputs

After `terraform apply`, the following outputs are available:

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR block |
| `igw_id` | Internet Gateway ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `public_subnet_azs` | Availability zones of public subnets |
| `nat_gateway_ids` | NAT Gateway IDs |
| `alb_security_group_id` | ALB security group ID |
| `windows_security_group_id` | Windows EC2 security group ID |
| `rds_security_group_id` | RDS SQL Server security group ID |

## Cost notes for the POC

- One NAT gateway adds ~$33/month plus data processing charges. It is enabled because it is production-like, but you can set `enable_nat_gateway = false` if the EC2 is in the public subnet and you do not need private subnet outbound access.
- One NAT gateway is created instead of one per AZ to save cost.
- Public subnets are used so the POC EC2 can have a public IP and Elastic IP without a bastion or ALB.
