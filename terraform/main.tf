provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "medicure_key" {
  key_name   = "medicure-key-${var.environment}"
  public_key = var.public_key
}

resource "aws_security_group" "medicure_sg" {
  name        = "medicure_sg"
  description = "Allow SSH and app traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For SSH access (restrict for production)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # App port open for testing
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # App port open for testing
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "test_server" {
  ami           = "ami-084568db4383264d4"  
  instance_type = "t2.micro"
  key_name      = aws_key_pair.medicure_key.key_name
  security_groups = [aws_security_group.medicure_sg.name]
  tags = {
    Name = "Medicure-Test-Server"
  }
}

resource "aws_instance" "prod_server" {
  count         = var.environment == "prod" ? 1 : 0
  ami           = "ami-084568db4383264d4"  
  instance_type = "t2.micro"
  key_name      = aws_key_pair.medicure_key.key_name
  security_groups = [aws_security_group.medicure_sg.name]
  tags = {
    Name = "Medicure-Prod-Server"
  }
}