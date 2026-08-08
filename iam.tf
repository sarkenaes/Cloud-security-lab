#vulnerable iam ROLE
#defines the role for an ec2 service
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
#attaches the role to this policy and gives it admin access
resource "aws_iam_role_policy_attachment" "ec2_admin"{
    role =aws_iam_role.ec2_vulnerable.name
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
#wrapper- dosnt have anything technically good, just there because aws cant attach ec2 instances directly to a policy so acts as wrapper
resource "aws_iam_instance_profile" "ec2_vulnerable"{
name = "${var.project_name}-ec2-profile"
role = aws_iam_role.ec2_vulnerable.name
}
