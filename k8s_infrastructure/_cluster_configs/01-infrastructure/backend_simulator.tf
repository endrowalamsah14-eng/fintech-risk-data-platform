# ==============================================================================
# ZONE 1: TRANSACTIONAL TIER (YUGABYTEDB SIMULATOR)
# ==============================================================================

resource "aws_security_group" "simulator_sg" {
  name        = "yugabyte-simulator-sg"
  description = "Allow inbound traffic for YugabyteDB and Native CDC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow PostgreSQL/YSQL Port"
    from_port   = 5433
    to_port     = 5433
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    description = "Allow YB-Master UI"
    from_port   = 7000
    to_port     = 7000
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

resource "aws_instance" "yugabyte_simulator" {
  ami           = "ami-0eb260c4d5475b901" 
  instance_type = "t3.large"
  subnet_id     = module.vpc.public_subnets[0]
  
  instance_market_options {
    market_type = "spot"
  }

  vpc_security_group_ids = [aws_security_group.simulator_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io docker-compose
              systemctl start docker
              systemctl enable docker
              EOF

  tags = {
    Name        = "emarket-yugabyte-simulator"
    Environment = "Prototype"
    Tier        = "OLTP-Source"
  }
}

output "yugabyte_simulator_ip" {
  value = aws_instance.yugabyte_simulator.public_ip
}