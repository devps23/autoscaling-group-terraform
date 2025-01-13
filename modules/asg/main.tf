// create a launch template
resource "aws_launch_template" "launch_template"{
  name = "test"
  image_id = data.aws_ami.ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.server_sg.id]
}
resource "aws_autoscaling_group" "scaling_group" {
  name = "asg"
  desired_capacity   = 1
  max_size           = 2
  min_size           = 1
  vpc_zone_identifier = var.subnets_id
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
}
# create target group
resource "aws_lb_target_group" "tg" {
  name               = "${var.env}-${var.component}-tg"
  port               = var.app_port
  protocol           = "HTTP"
  vpc_id             = var.vpc_id
deregistration_delay = 50
  health_check {
  path = "/health"
  port = var.app_port
  healthy_threshold = 2
  unhealthy_threshold = 2
  interval = 5
  timeout =  2
}
tags = {
Name = "${var.env}-${var.component}-tg"
}
}
# create load balancer
resource "aws_lb" "lb" {
  name               = "${var.env}-${var.component}-lb"
  internal           = var.lb_internal_facing == "public" ? false : true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.lb_subnets
  tags = {
    Environment = "${var.env}-${var.component}-lb"
  }
}
# create a load balancer security group
resource "aws_security_group" "lb_sg" {
  name        = "${var.env}-vsg-${var.component}-lbsg"
  description = "${var.env}-vsg-${var.component}-lbsg"
  vpc_id      = var.vpc_id
  dynamic "ingress" {
    for_each = var.lb_app_port
    content {
      from_port   =  ingress.value
      to_port     =  ingress.value
      protocol    = "TCP"
      cidr_blocks = var.lb_app_port_cidr
    }
  }
  egress {
    from_port   =  0
    to_port     =  0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.env}-vsg-${var.component}-lbsg"
  }
}
# create a server security group
resource "aws_security_group" "server_sg" {
  name        = "${var.env}-vsg-${var.component}-serversg"
  description = "${var.env}-vsg-${var.component}-serversg"
  vpc_id      = var.vpc_id
  ingress {
    from_port   =  var.app_port
    to_port     =  var.app_port
    protocol    = "TCP"
    cidr_blocks = var.server_app_port_cidr
  }
  ingress {
    from_port   =  22
    to_port     =  22
    protocol    = "TCP"
    cidr_blocks = var.bastion_nodes
  }
  egress {
    from_port   =  0
    to_port     =  0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.env}-vsg-${var.component}-serversg"
  }
}
