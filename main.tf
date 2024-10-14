provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create Internet Gateway for public access
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

# Create route table for public access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# Security Group for Ubuntu public access
resource "aws_security_group" "ubuntu_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH from anywhere
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTP from anywhere
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTPS from anywhere
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # ICMP from anywhere
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # All outbound traffic
  }
}

# Security Group for Amazon Linux local access
resource "aws_security_group" "linux_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # SSH only within VPC
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # HTTP only within VPC
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # HTTPS only within VPC
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.main.cidr_block] # ICMP only within VPC
  }
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Outbound SSH only to VPC
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Outbound HTTP only to VPC
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Outbound HTTPS only to VPC
  }
}

# Create Ubuntu EC2 instance
resource "aws_instance" "ubuntu" {
  ami                    = "ami-0084a47cc718c111a" # Latest Ubuntu AMI in us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.ubuntu_sg.id]  # Use vpc_security_group_ids instead of security_groups
  key_name = "g_linux"
  tags = {
    Name = "Ubuntu-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y nginx
              echo "Hello World - $(lsb_release -a)" | sudo tee /var/www/html/index.html
              sudo systemctl start nginx
              sudo systemctl enable nginx
              
              # Install Docker
              sudo apt-get update
              sudo apt-get install -y ca-certificates curl
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list
              sudo apt-get update
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo systemctl start docker
              sudo systemctl enable docker
              EOF
}


# Create Amazon Linux EC2 instance
resource "aws_instance" "amazon_linux" {
  ami                    = "ami-0592c673f0b1e7665" # Latest Amazon Linux 2 AMI in us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.linux_sg.id]  # Use vpc_security_group_ids instead of security_groups
  key_name = "g_linux"
  tags = {
    Name = "Amazon-Linux-Server"
  }
}




output "ubuntu_public_ip" {
  value = aws_instance.ubuntu.public_ip
}

output "ubuntu_private_ip" {
  value = aws_instance.ubuntu.private_ip
}

output "amazon_linux_private_ip" {
  value = aws_instance.amazon_linux.private_ip
}
