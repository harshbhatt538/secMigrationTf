region      = "ap-south-1"
project     = "mcloud"
environment = "poc"

vpc_cidr             = "10.0.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# POC cost-saving: one NAT gateway. For production, set single_nat_gateway = false
# to create one NAT gateway per AZ for high availability.
enable_nat_gateway = false
single_nat_gateway = true

# Replace with your office / admin IP before applying.
# Examples:
#   admin_cidr_blocks = ["203.0.113.10/32"]
# Leave empty if you use AWS Systems Manager Session Manager only.
admin_cidr_blocks = []

# Replace with the CIDR block(s) of customer / device networks if you test legacy devices.
# Current-generation devices use HTTPS/443 and do not need this.
device_cidr_blocks = []

# Open HTTP/HTTPS to the internet for POC testing
windows_web_cidr_blocks = ["0.0.0.0/0"]

# Windows application server
ec2_instance_type    = "t3.medium"
ec2_key_name         = ""
ec2_root_volume_size = 50
ec2_data_volume_size = 0
ec2_create_eip       = false
