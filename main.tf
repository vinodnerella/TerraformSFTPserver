#sftp terraform project

#1. Create vpc
#2. Create Internet Gateway
#3. Create Custom Route Table
#4. Create a Public and Private Subnet 
#5. Associate subnet with Route Table
#6. Create Security Group to allow port 21,22
#7. Create a network interface with an ip in the public subnet that was created in step 4
#8. Assign an elastic IP to the network interface created in step 7
#s9. Create Ubuntu 18.04 server with predefined key and setup ftp service(setup-ftp.sh) in the public subnet

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = "access-key"
  secret_key = "secret-key"
}



# 1. Create vpc

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev-vpc.id
}

# 3. Create Custom Route Table

resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "dev"
  }
}

# 4. Create a Public and Private Subnet

resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.dev-route-table.id
}

# 6. Create Security Group to allow port 21,22
resource "aws_security_group" "allow_ftp" {
  name        = "allow_ftp_conection"
  description = "Allow inbound ftp connection"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "FTP"
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  tags = {
    Name = "allow_ftp"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "ftp-server-nic" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_ftp.id]

}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.ftp-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create Ubuntu server

resource "aws_instance" "ftp-server-instance" {
  ami               = "ami-085925f297f89fce1"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "test_terraform"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ftp-server-nic.id
  }

   provisioner "file" {
    source      = "vsftpd.conf"
    destination = "/home/ubuntu/vsftpd.conf"
  }

  connection {
    host = self.public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file("/Users/vinodnerella/Downloads/test_terraform.pem")
  }

  user_data = "${file("setup-ftp.sh")}"

  tags = {
    Name = "ftp-server"
  }
}


output "server_private_ip" {
  value = aws_instance.ftp-server-instance.private_ip

}

output "server_id" {
  value = aws_instance.ftp-server-instance.id
}

