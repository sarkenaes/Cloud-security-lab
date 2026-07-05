resource "aws_db_instance" "vulnerable" {
  allocated_storage    = 10
  db_name              = "vul_db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "password123"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible= true
  storage_encrypted=false
  db_subnet_group_name = aws_db_subnet_group.vulnerable.name
vpc_security_group_ids = [aws_security_group.vulnerable.id]
    tags={
    Name ="${var.project_name}-vulnerable-db"
    Project =var.project_name

  }
}
resource "aws_db_subnet_group" "vulnerable" {
  name       = var.project_name
subnet_ids = [aws_subnet.public.id, aws_subnet.public_2.id]
  tags = {
    Name = "${var.project_name}-vulnerable-db"
  }
}