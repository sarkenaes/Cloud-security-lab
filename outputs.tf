output "ec2_public_ip"{
  value= aws_instance.vulnerable.public_ip
}
