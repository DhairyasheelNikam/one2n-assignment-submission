terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Creating a S3 Bucket:
resource "aws_s3_bucket" "new_bucket" {
  bucket = "one2n-assignment-bucket"
}

# Creating a few directories inside the S3 Bucket:
resource "aws_s3_object" "parent_dir_1" {
  bucket = aws_s3_bucket.new_bucket.bucket
  key    = "parent-dir-1/"
  acl    = "private"
}

resource "aws_s3_object" "parent_dir_2" {
  bucket = aws_s3_bucket.new_bucket.bucket
  key    = "parent-dir-2/"
  acl    = "private"
}

resource "aws_s3_object" "child_dir_1" {
  bucket = aws_s3_bucket.new_bucket.bucket
  key    = "parent-dir-1/child-dir-1/"
  acl    = "private"
}

# Creating an IAM Role for EC2 to access S3:
resource "aws_iam_role" "terraform_user" {
  name               = "terraform_access_role"
  assume_role_policy = file("assume_role_policy.json")
}

# Attaching policy to EC2 Role for S3 access
resource "aws_iam_role_policy" "user_s3_access" {
  name   = "user_s3_access_policy"
  role   = aws_iam_role.terraform_user.id
  policy = file("iam_role_policy.json")
}

resource "aws_iam_instance_profile" "terraform_access_instance_profile-new" {
  name = "terraform_access_instance_profile-new"
  role = aws_iam_role.terraform_user.name
}

# Creating an EC2 Instance:
resource "aws_instance" "assignment_ec2_machine" {
  ami                  = "ami-01816d07b1128cd2d"
  instance_type        = "t2.micro"
  security_groups      = [aws_security_group.new_sg.name]
  iam_instance_profile = aws_iam_instance_profile.terraform_access_instance_profile-new.name

  user_data = <<-EOF
              #!/bin/bash
              
              # Installing required Packages:
              sudo su
              sudo yum update -y
              sudo yum install python3 python3-pip -y
              sudo pip3 install flask boto3

              mkdir -p /home/dnikam/app

              # Invoking and Running the Python script into the EC2 Instance:
              cat <<EOL > /home/dnikam/app/http_service_code.py
              ${file("http_service_code.py")}
              EOL
              
              sudo chmod +x /home/dnikam/app/http_service_code.py
              echo "Starting the Python script"
              sudo nohup python3 /home/dnikam/app/http_service_code.py > /home/dnikam/app/http_service_output.log 2>&1 &
            EOF
}

# Setting up the Security Group for the EC2 instance:
resource "aws_security_group" "new_sg" {
  name        = "app_security_group"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
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

output "flask_app_url" {
  value = "http://${aws_instance.assignment_ec2_machine.public_ip}:5000/list-bucket-content/"
}