output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gw.id
}

output "app_server_public_ip" {
  description = "The public IP address of the Application Server"
  value       = aws_instance.app_server.public_ip
}

output "app_server_private_ip" {
  description = "The private IP address of the Application Server"
  value       = aws_instance.app_server.private_ip
}

output "db_server_private_ip" {
  description = "The private IP address of the Database Server"
  value       = aws_instance.db_server.private_ip
}
