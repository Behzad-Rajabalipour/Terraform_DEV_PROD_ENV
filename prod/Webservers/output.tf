output "private_instance_ips" {
  value = aws_instance.private_instance[*].private_ip
}
