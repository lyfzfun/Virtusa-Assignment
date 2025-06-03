provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Stage = "Test"
    }
  }
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Use default VPC subnets
data "aws_subnets" "public" {
   filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 2 default public subnets → used for ALB + NAT.
locals {
  public_subnet_ids = data.aws_subnets.public.ids
}

# 2 new private subnets → used for EC2 ASG.
resource "aws_subnet" "private_1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.100.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.101.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "PrivateSubnet2"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = local.public_subnet_ids[0]

  depends_on = [aws_eip.nat_eip]
}

resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Internet Gateway
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# S3 Bucket for Web Content
resource "aws_s3_bucket" "web_content" {
  bucket = "private-web-content-bucket-shweta"
  tags = {
    Name = "WebContentBucket"
  }
}

resource "aws_s3_object" "web_files" {
  for_each = fileset("web_content", "**")

  bucket = aws_s3_bucket.web_content.bucket
  key    = each.value
  source = "web_content/${each.value}"
  etag   = filemd5("web_content/${each.value}")
}

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_read_role" {
  name = "ec2-s3-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_readonly" {
  role       = aws_iam_role.ec2_s3_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_read_role.name
}

# Security Groups
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow Traffic from ALB only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template
resource "aws_launch_template" "web_template" {
  name_prefix   = "web-template"
  image_id      = "ami-0afc7fe9be84307e4" # Amazon Linux 2 (Singapore)
  instance_type = "t2.micro"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
    user_data     = base64encode(<<-EOF
    #!/bin/bash
    yum install -y nginx aws-cli
    aws s3 cp s3://private-web-content-bucket-shweta/ /usr/share/nginx/html/ --recursive
    systemctl enable nginx
    systemctl start nginx
  EOF
  )
}

# ALB
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            =  [
    local.public_subnet_ids[0],
    local.public_subnet_ids[1]
  ]
  security_groups    = [aws_security_group.web_sg.id]
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 3
  max_size            = 5
  min_size            = 1
  vpc_zone_identifier = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Stage"
    value               = "Test"
    propagate_at_launch = true
  }
}
