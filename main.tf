terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "teraform-state-haashim"
    key    = "global/s3/terraform.tfstate"
    region = "eu-west-1"
    dynamodb_table = "terraform_state_locking"
    encrypt = true
  }
}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod-public"
  }
}

resource "aws_nat_gateway" "a" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.private-subnet-1.id
}

resource "aws_nat_gateway" "b" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.private-subnet-2.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public-subnet-2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "public-2"
  }
}

resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "private-1"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.4.0/24"
  tags = {
    Name = "private-2"
  }
}

resource "aws_security_group" "prod-SG" {
  name = "production security group"
  description = "production security group"
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH"
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
}

resource "aws_instance" "example-ec2" {
  ami           = "ami-013898da85dead62b"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.public-subnet-1.id
  security_groups = [aws_security_group.prod-SG.id]
  key_name = "main-key"

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras enable epel -y
              sudo yum install epel-release -y
              sudo yum install nginx -y
              sudo systemctl start nginx.service
              EOF

  tags = {
    Name = "prod-ec2"
  }
}

# resource "aws_s3_bucket" "teraform_state" {
#   bucket = "teraform-state-haashim"

#   lifecycle {
#     prevent_destroy = true
#   }

#   versioning {
#     enabled = true
#   }

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

# resource "aws_dynamodb_table" "terraform_locks" {
#   name = "terraform_state_locking"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   lifecycle {
#     prevent_destroy = true
#   }
# }
