resource "aws_iam_role" "ec2_vulnerable"{
    name ="${var.project_name}-ec2-role"
    assume_role_policy=jsonencode({
    Version ="2012-10-17"
    Statement=[{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal ={
                    Service = "ec2.amazonaws.com"
        }
    }] 
    })
}
resource "aws_iam_role_policy_attachment" "ec2_admin"{
    role =aws_iam_role.ec2_vulnerable.name
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_iam_instance_profile" "ec2_vulnerable"{
name = "${var.project_name}-ec2-profile"
role = aws_iam_role.ec2_vulnerable.name

}
