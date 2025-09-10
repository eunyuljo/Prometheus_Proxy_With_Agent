data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "description"
    values = ["*"]
  }
}

resource "aws_security_group" "prometheus_sg" {
  name_prefix = "prometheus-sg-"
  vpc_id      = module.vpc_1.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 50051
    to_port     = 50051
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
    Name = "prometheus-security-group"
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Role"

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
    Name = "EC2-SSM-Role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-InstanceProfile"
  role = aws_iam_role.ssm_role.name

  tags = {
    Name = "EC2-SSM-InstanceProfile"
  }
}

resource "aws_instance" "prometheus_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  
  subnet_id              = module.vpc_1.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  
  user_data = base64encode(file("${path.module}/user-data-prometheus.sh"))

  tags = {
    Name = "prometheus-server-vpc1"
  }
}

resource "aws_eip" "prometheus_server_eip" {
  domain   = "vpc"
  instance = aws_instance.prometheus_server.id

  depends_on = [aws_instance.prometheus_server]

  tags = {
    Name = "prometheus-server-eip"
  }
}

resource "aws_security_group" "prometheus_proxy_agent_sg" {
  name_prefix = "prometheus-proxy-agent-sg-"
  vpc_id      = module.vpc_2.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
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
    Name = "prometheus-proxy-agent-security-group"
  }
}


resource "aws_instance" "prometheus_proxy_agent" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  
  subnet_id              = module.vpc_2.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.prometheus_proxy_agent_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  

  user_data = base64encode(templatefile("${path.module}/user-data-proxy-agent.sh", {
    prometheus_proxy_ip = aws_eip.prometheus_server_eip.public_ip,
    private_instance_ip = aws_instance.private_instance.private_ip
  }))

  #### Proxy_agent의 경우 Prometheus 서버의 IP 가 필요하므로, 해당 IP를 먼저 확보하고 진행하도록 depends_on을 적용한다.
  depends_on = [aws_eip.prometheus_server_eip, aws_instance.private_instance]

  tags = {
    Name = "prometheus-proxy-agent"
  }
}

resource "aws_eip" "prometheus_proxy_agent_eip" {
  domain   = "vpc"
  instance = aws_instance.prometheus_proxy_agent.id

  depends_on = [aws_instance.prometheus_proxy_agent]

  tags = {
    Name = "prometheus-proxy-agent-eip"
  }
}

resource "aws_security_group" "private_instance_sg" {
  name_prefix = "private-instance-sg-"
  vpc_id      = module.vpc_2.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.vpc_2.vpc_cidr_block]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [module.vpc_2.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-instance-security-group"
  }
}

resource "aws_instance" "private_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  
  subnet_id              = module.vpc_2.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  
  user_data = base64encode(file("${path.module}/user-data-node-exporter.sh"))

  tags = {
    Name = "private-instance-vpc2"
  }
}