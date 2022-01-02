terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
  access_key = "access_key"
  secret_key = "secret_key"
}

resource "aws_vpc" "My_vpc" {
    cidr_block= "10.0.0.0/16"
    tags = {
      "Name" = "MyVPC"
    }
}

resource "aws_internet_gateway" "MyIGW" {
  vpc_id = aws_vpc.My_vpc.id

  tags = {
    Name = "MyIGW"
  }
}

resource "aws_route_table" "MyRT" {
  vpc_id = aws_vpc.My_vpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyIGW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.MyIGW.id
  }

  tags = {
    Name = "MyRT"
  }
}

variable "subnet_cidr" {
  description="cidr prefix for subnet"
  default = "10.0.0.0/28"
}

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.My_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    tags={
        "Name"="Pivate-sub"
    }
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.My_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"
    tags={
        "Name"="Public-Sub"
    }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.MyRT.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.My_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
   ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "WebNIC" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.0.10"]
  security_groups = [aws_security_group.allow_web.id]

  
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.WebNIC.id
  associate_with_private_ip = "10.0.0.10"
  depends_on = [aws_internet_gateway.MyIGW]

}

output "server_public_ip" {
    value=aws_eip.one.public_ip  
}

 resource "aws_instance" "WebServer" {
   ami = "ami-0c1a7f89451184c8b"
   instance_type = "t2.micro"
   availability_zone = "ap-south-1a"
   key_name = "my-webserver"

   network_interface{
    device_index = 0
    network_interface_id = aws_network_interface.WebNIC.id
  }
   user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo First Terraform web > /var/www/html/index.html"
                EOF
   tags = {
     "Name" = "Terraform_web"
   }
 }