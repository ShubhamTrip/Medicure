output "master_ip" {
  value = aws_instance.k8s-master.public_ip
}

output "worker_ips" {
  value = [for instance in aws_instance.k8s-worker : instance.public_ip]
}