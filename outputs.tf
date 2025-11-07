# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = { for name, inst in aws_instance.web_app : name => inst.id }
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = { for name, inst in aws_instance.web_app : name => inst.public_ip }
}

output "instance_name" {
  description = "Tags of the EC2 instance"
  value       = { for name, inst in aws_instance.web_app : name => inst.tags.Name }
}
