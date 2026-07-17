data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}
resource "aws_security_group" "vulnerable"{
name = "${var.project_name}-vulnrable-sg"
description = "Intentionally vulnerable security group"
vpc_id=aws_vpc.main.id

ingress{
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
    description= "Allow all inbound,intentionally vulnerable"
}
egress{
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
    description ="Allow all outbound"
}
tags={
    Name ="${var.project_name}-vulnerable-sg"
    Project =var.project_name

}
}
resource "aws_key_pair" "vulnerable"{
    key_name= "${var.project_name}-key"
    public_key = file("~/.ssh/cloud-lab-key.pub")
}
resource "aws_instance" "vulnerable"{
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    subnet_id=aws_subnet.public.id
    vpc_security_group_ids =[aws_security_group.vulnerable.id]
    key_name =aws_key_pair.vulnerable.key_name
    iam_instance_profile=aws_iam_instance_profile.ec2_vulnerable.name
}
