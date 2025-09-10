output "vpc_1_info" {
  description = "VPC 1 information"
  value = {
    vpc_id              = module.vpc_1.vpc_id
    vpc_cidr_block      = module.vpc_1.vpc_cidr_block
    public_subnets      = module.vpc_1.public_subnets
    private_subnets     = module.vpc_1.private_subnets
    internet_gateway_id = module.vpc_1.igw_id
    public_route_table_ids  = module.vpc_1.public_route_table_ids
    private_route_table_ids = module.vpc_1.private_route_table_ids
  }
}

output "vpc_2_info" {
  description = "VPC 2 information"
  value = {
    vpc_id              = module.vpc_2.vpc_id
    vpc_cidr_block      = module.vpc_2.vpc_cidr_block
    public_subnets      = module.vpc_2.public_subnets
    private_subnets     = module.vpc_2.private_subnets
    internet_gateway_id = module.vpc_2.igw_id
    public_route_table_ids  = module.vpc_2.public_route_table_ids
    private_route_table_ids = module.vpc_2.private_route_table_ids
  }
}

output "prometheus_instance_info" {
  description = "Prometheus instance information in VPC 1"
  value = {
    instance_id       = aws_instance.prometheus_server.id
    private_ip        = aws_instance.prometheus_server.private_ip
    elastic_ip        = aws_eip.prometheus_server_eip.public_ip
    public_dns        = aws_eip.prometheus_server_eip.public_dns
    instance_type     = aws_instance.prometheus_server.instance_type
    availability_zone = aws_instance.prometheus_server.availability_zone
  }
}

output "prometheus_proxy_agent_info" {
  description = "Prometheus proxy agent information in VPC 2"
  value = {
    instance_id       = aws_instance.prometheus_proxy_agent.id
    private_ip        = aws_instance.prometheus_proxy_agent.private_ip
    elastic_ip        = aws_eip.prometheus_proxy_agent_eip.public_ip
    public_dns        = aws_eip.prometheus_proxy_agent_eip.public_dns
    instance_type     = aws_instance.prometheus_proxy_agent.instance_type
    availability_zone = aws_instance.prometheus_proxy_agent.availability_zone
  }
}

output "private_instance_info" {
  description = "Private instance information in VPC 2"
  value = {
    instance_id       = aws_instance.private_instance.id
    private_ip        = aws_instance.private_instance.private_ip
    instance_type     = aws_instance.private_instance.instance_type
    availability_zone = aws_instance.private_instance.availability_zone
    subnet_id         = aws_instance.private_instance.subnet_id
  }
}