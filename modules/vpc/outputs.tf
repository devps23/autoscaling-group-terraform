output "vpc_id"{
  value = aws_vpc.vpc.id
}
output "frontend_subnets" {
  value = aws_subnet.frontend_subnets.*.id
}
output "backend_subnets" {
  value = aws_subnet.backend_subnets.*.id
}
output "mysql_subnets" {
  value = aws_subnet.mysql_subnets.*.id
}
output "public_subnets" {
  value = aws_subnet.public_subnets.*.id
}
