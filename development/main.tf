resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

#subnets
resource "aws_subnet" "PublicSubnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "PublicSubnet2" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.20.0/24"

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_subnet" "PrivateSubnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.30.0/24"

  tags = {
    Name = "PrivateSubnet"
  }
}

#IGW
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

#NAT
resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.PublicSubnet1.id

  tags = {
    Name = "NAT"
  }
}

#route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route" "Public_Route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.IGW.id
}

resource "aws_route_table_association" "Public_Route_association1" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "Public_Route_association2" {
  subnet_id      = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "PrivateRouteTable" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route" "PrivateRoute" {
  route_table_id         = aws_route_table.PrivateRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.NAT.id
}

resource "aws_route_table_association" "Private_Route_Association" {
  subnet_id      = aws_subnet.PrivateSubnet.id
  route_table_id = aws_route_table.PrivateRouteTable.id

}
# alb sg
resource "aws_security_group" "ALB_Security_Group" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "ALB-Security-Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress" {
  security_group_id = aws_security_group.ALB_Security_Group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.ALB_Security_Group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#bastion sg

resource "aws_security_group" "Bastion_Security_Group" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Bastion-Security-Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ingress" {
  security_group_id = aws_security_group.Bastion_Security_Group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_egress" {
  security_group_id = aws_security_group.Bastion_Security_Group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

#instance security group

resource "aws_security_group" "ec2_ssh" {
  vpc_id = aws_vpc.main.id

}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh_ingress" {
  security_group_id            = aws_security_group.ec2_ssh.id
  referenced_security_group_id = aws_security_group.Bastion_Security_Group.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  security_group_id            = aws_security_group.ec2_ssh.id
  referenced_security_group_id = aws_security_group.ALB_Security_Group.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}
resource "aws_vpc_security_group_egress_rule" "ec2_ssh_egress" {
  security_group_id            = aws_security_group.ec2_ssh.id
  referenced_security_group_id = aws_security_group.Bastion_Security_Group.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}
resource "aws_vpc_security_group_egress_rule" "ec2_http_egress" {
  security_group_id = aws_security_group.ec2_ssh.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}



#instance

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.12.20260930.0-kernel-6.18-x86_64*"]
  }
}
#ec2 instance
resource "aws_instance" "app_instance" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.bastion.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  subnet_id              = aws_subnet.PrivateSubnet.id
  vpc_security_group_ids = [aws_security_group.ec2_ssh.id]
  user_data              = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install wget -y
    dnf install ruby -y
    wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latestv2/install
    sleep 20
    chmod +x ./install
    sudo ./install auto
    systemctl enable --now codedeploy-agent
    EOF
  tags = {
    Name = "app-instance"
  }
}
# ec2 instance profile
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    name = "ec2-ssm"
  }
}
resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

#bastion instance
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "bastion" {
  key_name   = "bastion"
  public_key = tls_private_key.bastion.public_key_openssh
}
resource "local_sensitive_file" "bastion" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "bastion-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "bastion_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.PublicSubnet1.id
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.Bastion_Security_Group.id]
  tags = {
    Name = "bastion-instance"
  }
}


#alb
resource "aws_lb" "main_alb" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB_Security_Group.id]
  subnets            = [aws_subnet.PublicSubnet1.id, aws_subnet.PublicSubnet2.id]

  tags = {
    Name = "main-alb"
  }
}
resource "aws_lb_target_group" "alb_target_group" {
  name        = "lb-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path = "/"
  }
}
resource "aws_lb_target_group_attachment" "instance_attachment" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.app_instance.id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

#codebuild 

resource "aws_iam_role" "codebuild_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "codebuild-role"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
#code deploy
resource "aws_codebuild_project" "codebuild_project" {
  name         = "codebuild-project"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }
  source {
    type     = "GITHUB"
    location = "https://github.com/cjones2182/6.AWS-Terraform-EC2-ALB-Bastion-CodeDeploy"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws_codebuild/standard:7.0"
  }
}

resource "aws_iam_role" "codedeploy_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_attach" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

