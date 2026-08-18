# mCloud Infrastructure Terraform

A modular Terraform project that creates the VPC, subnets, routing, security groups, and Windows EC2 application server for the mCloud migration POC. It is intentionally small and simple for the POC, but structured so it can be extended to a production deployment.

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
    ├── security_groups/     # ALB, Windows EC2, and RDS security groups
    └── ec2/                 # Windows application server
```

## What it creates

- **VPC** `mcloud-poc-vpc` (`10.0.0.0/16`) with DNS hostnames and DNS support enabled.
- **Internet Gateway** attached to the VPC.
- **Public subnets** in `ap-south-1a` and `ap-south-1b` with auto-assign public IP enabled (for NAT gateways and future ALB).
- **Private subnets** in `ap-south-1a` and `ap-south-1b` for EC2 and RDS.
- **NAT Gateway**: disabled by default in `terraform.tfvars` (`enable_nat_gateway = false`) for the public-EC2 POC. Set to `true` and `single_nat_gateway = false` for production.
- **Route tables**:
  - Public route table sends `0.0.0.0/0` to the Internet Gateway.
  - Private route table sends `0.0.0.0/0` to the NAT gateway when NAT is enabled; otherwise it contains only the local VPC route.
- **Security groups**:
  - `mcloud-poc-alb-sg`: allows 80/443 from the internet.
  - `mcloud-poc-windows-sg`: allows 80/443 from the ALB SG, optionally 80/443 from `windows_web_cidr_blocks` (use this for direct public EC2 access), optionally 80/443 + 3389 from `admin_cidr_blocks`, and optionally 9040 from `device_cidr_blocks`.
  - `mcloud-poc-rds-sg`: allows 1433 from the Windows EC2 security group only.
- **Windows EC2 application server** (`mcloud-poc-windows`):
  - Windows Server 2022 Base (latest AMI)
  - `t3.medium` instance type (POC minimum, override as needed)
  - 50 GB encrypted `gp3` root volume
  - Optional data volume for `C:\MA\Storage` and logs
  - IAM role with SSM and CloudWatch agent permissions
  - Optional Elastic IP (disabled by default)
  - User-data bootstrap script installs IIS, .NET 8 Hosting Bundle, URL Rewrite, Node.js LTS, Git, AWS CLI, and CloudWatch agent

## How to use

1. Install Terraform and authenticate to AWS (environment variables or `~/.aws/credentials`).
2. Update `terraform.tfvars`:
   - Change `admin_cidr_blocks` to your public IP if you want direct RDP (and optional HTTP/HTTPS) access to the EC2.
   - Change `windows_web_cidr_blocks` to `["0.0.0.0/0"]` for public HTTP/HTTPS access when no ALB is used, or set to your IP for restricted access.
   - Change `device_cidr_blocks` if you test legacy devices on port 9040.
3. Run:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

4. After apply, Terraform prints the VPC, subnet, security group, and EC2 outputs. Use the EC2 public IP and the RDS security group ID for the next steps:
   - Create the RDS SQL Server instance (`mcloud-poc-rds-sg`) in the private subnets.
   - RDP or SSM into the EC2 instance and complete the mCloud API/Web deployment.
   - Optionally create an Application Load Balancer (`mcloud-poc-alb-sg` and public subnets) when moving to production.

## Configuration created by default (`terraform.tfvars`)

```hcl
region      = "ap-south-1"
project     = "mcloud"
environment = "poc"
vpc_cidr    = "10.0.0.0/16"

azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

enable_nat_gateway = false
single_nat_gateway = true

admin_cidr_blocks       = []
windows_web_cidr_blocks = ["0.0.0.0/0"]
device_cidr_blocks      = []

# Windows application server
ec2_instance_type    = "t3.medium"
ec2_key_name         = ""
ec2_root_volume_size = 50
ec2_data_volume_size = 0
ec2_create_eip       = false
```

## Public EC2 / no ALB mode

The default `terraform.tfvars` is configured for a POC where the Windows EC2 has a public IP and no Application Load Balancer is used. In this mode:

- `enable_nat_gateway = false` — no NAT gateway is created because the EC2 is in a public subnet and uses the Internet Gateway directly.
- `windows_web_cidr_blocks = ["0.0.0.0/0"]` — HTTP/HTTPS is opened directly to the EC2.
- The RDS SQL Server stays in a private subnet with no outbound internet. The EC2 in the public subnet can still reach RDS over the internal VPC network.

When you move to production, switch to an ALB and private EC2 by setting:

```hcl
enable_nat_gateway      = true
single_nat_gateway      = false
windows_web_cidr_blocks = []
admin_cidr_blocks       = []
```

Then place the EC2 in the private subnets and create an Application Load Balancer in the public subnets using `alb_security_group_id`.

## EC2 bootstrap prerequisites

The user-data script (`modules/ec2/bootstrap.ps1.tpl`) installs everything the mCloud documentation lists for the application server:

- **Windows Server 2022 Base** AMI (latest from Amazon).
- **IIS** with the role services required by the mCloud installation guide:
  - Core web server, static content, default document, directory browsing, HTTP errors, HTTP redirection
  - ASP.NET 4.8 (`Web-Asp-Net45`, `Web-Net-Ext45`, `Web-ISAPI-Ext`, `Web-ISAPI-Filter`)
  - Basic authentication, Windows authentication, request filtering, WebSocket protocol
  - Static and dynamic compression, HTTP logging, request monitor, HTTP tracing
  - IIS management console and compatibility/metabase tools
- **.NET 8 Hosting Bundle** — provides the .NET 8 runtime, ASP.NET Core 8 runtime, and the ASP.NET Core Module (ANCM) for IIS.
- **IIS URL Rewrite 2.1** — required for React client-side routing.
- **.NET 8 SDK** — for building/publishing `mCloud.API`.
- **Node.js LTS** and **npm** — for building `mCloud.Web`.
- **Git** — for cloning the repository.
- **AWS CLI v2** and **CloudWatch agent** — for monitoring and SSM.
- Creates the `C:\MA` installation root folder.

### Additional / optional things

- **SQL Server client tools (`sqlcmd`)**: Not installed by default because the RDS SQL Server endpoint is used. If you want to test RDS connectivity from the EC2, uncomment the `sql-server-management-studio` Chocolatey line in `bootstrap.ps1.tpl` or install `MsSqlCmdLnUtils` from Microsoft.
- **mCloud application binaries**: The bootstrap script does not download the actual mCloud release. After the EC2 is ready, clone the `MA` code and run `Setup-IIS.ps1`, `dotnet publish`, and `npm run build` manually (or add those steps to the bootstrap script later).
- **Data volume**: If you set `ec2_data_volume_size > 0`, the script initializes the disk as drive `D:\`. You can then move `C:\MA\Storage` and logs to `D:\MA`.
- **SSL certificate**: For HTTPS you must import a certificate into IIS and bind it to port 443. For a POC you can use a self-signed certificate; for production use ACM with an ALB or a certificate from a trusted CA.

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
environment             = "prod"
single_nat_gateway      = false
admin_cidr_blocks       = []
windows_web_cidr_blocks = []
device_cidr_blocks      = []
```

- `single_nat_gateway = false` creates one NAT gateway per AZ for high availability.
- `admin_cidr_blocks = []` removes direct RDP/HTTP/HTTPS access. Use AWS Systems Manager Session Manager or a bastion host instead.
- `device_cidr_blocks` should be populated only with known customer/device network ranges; current-generation devices use HTTPS/443 and do not need port 9040.

### 3. Security groups

- Restrict the **ALB security group** to known office, VPN, or WAF IPs. Consider adding AWS WAF in front of the ALB.
- Remove direct `admin_cidr_blocks` and `windows_web_cidr_blocks` access from the **Windows EC2 security group** so it accepts traffic only from the ALB SG.
- Add VPC Flow Logs, AWS Network Firewall, or AWS Shield Advanced as required.

### 4. Subnet placement

- Place the **Windows EC2** and **RDS SQL Server** in the **private subnets**.
- Keep only the **ALB** and **NAT gateways** in the public subnets.
- Use an Application Load Balancer in the public subnets to terminate HTTPS and forward to the EC2 in the private subnets.

### EC2 instance

- Move the EC2 to the private subnets and remove its public IP. Access it only through SSM, a bastion host, or the ALB.
- Use a Launch Template and Auto Scaling Group (min 1, max 2) instead of a standalone `aws_instance` for availability and patching.
- Build a golden AMI with the bootstrap prerequisites pre-installed so instance launch is fast and reproducible.
- Attach an Elastic IP only to a bastion host, not to the application server.
- Add the EC2 to a Patch Manager patch baseline for automated Windows updates.

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
| `ec2_instance_id` | Windows EC2 instance ID |
| `ec2_public_ip` | Windows EC2 public IP |
| `ec2_private_ip` | Windows EC2 private IP |
| `ec2_public_dns` | Windows EC2 public DNS |
| `ec2_iam_role_name` | IAM role name attached to the EC2 |

## Cost notes for the POC

- `enable_nat_gateway = false` in the default `terraform.tfvars` saves ~$33/month because the public EC2 does not need a NAT gateway.
- When you move to production, set `enable_nat_gateway = true` and `single_nat_gateway = false` to create one NAT gateway per AZ for high availability.
- `windows_web_cidr_blocks = ["0.0.0.0/0"]` opens HTTP/HTTPS directly to the EC2 because no ALB is used. For production, use an ALB and set `windows_web_cidr_blocks = []`.
