resource "aws_instance" "main" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.windows_2022.id
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # Use a dynamic public IP only if we are not creating an Elastic IP.
  associate_public_ip_address = !var.create_eip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-root"
    })
  }

  user_data = templatefile("${path.module}/bootstrap.ps1.tpl", {
    data_volume_drive = var.data_volume_size > 0 ? "D" : ""
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-windows"
  })

  depends_on = [aws_iam_instance_profile.ec2]
}

resource "aws_eip" "main" {
  count  = var.create_eip ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eip"
  })
}

resource "aws_eip_association" "main" {
  count         = var.create_eip ? 1 : 0
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main[0].id
}

resource "aws_ebs_volume" "data" {
  count             = var.data_volume_size > 0 ? 1 : 0
  availability_zone = aws_instance.main.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-data"
  })
}

resource "aws_volume_attachment" "data" {
  count                          = var.data_volume_size > 0 ? 1 : 0
  device_name                    = "xvdf"
  volume_id                      = aws_ebs_volume.data[0].id
  instance_id                    = aws_instance.main.id
  stop_instance_before_detaching = true
}
