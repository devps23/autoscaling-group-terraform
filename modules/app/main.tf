# create an instance
resource "aws_instance" "instance" {
  ami = data.aws_ami.ami.image_id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.server_sg.id]
  subnet_id = var.subnets_id[0]
#   to encrypt the ec2 servers disk with the help of kms key id
  root_block_device{
    encrypted  = true
    kms_key_id = var.kms_key_id
  }
   instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "stop"
      spot_instance_type             = "persistent"
    }
  }
  tags = {
    Name = "${var.env}-${var.component}-demo"
    monitor = "yes"

  }
  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}


resource "null_resource" "null_instance" {
#   for every instance id is updated the updated instance id to trigger in null instance also
  triggers = {
    instance = aws_instance.instance.id
  }
  connection {
    type     = "ssh"
    user     = jsondecode(data.vault_generic_secret.my_secret.data_json).username
    password = jsondecode(data.vault_generic_secret.my_secret.data_json).password
    host     = aws_instance.instance.private_ip

  }
  provisioner "remote-exec" {
    inline = [
      "sudo dnf install ansible -y",
      "sudo pip3.11 install ansible hvac",
      "ansible-pull -i localhost, -U https://github.com/devps23/expense-rds-ansible get-secrets.yml -e env=${var.env} -e component_name=${var.component} -e vault_token=${var.vault_token}",
      "ansible-pull -i localhost, -U https://github.com/devps23/expense-rds-ansible expense.yml -e env=${var.env} -e component_name=${var.component} -e @~/secrets.json"
    ]
  }
}
resource "aws_route53_record" "server_record" {
  count      = var.lb_required ? 0 : 1
  name      = "${var.component}-${var.env}"
  type      = "A"
  zone_id   = var.zone_id
  ttl       = 5
  records = [aws_instance.instance.private_ip]
}
resource "aws_route53_record" "lb_record" {
  count      = var.lb_required  ? 1 : 0
  name      = "${var.component}-${var.env}-lb-record"
  type      = "CNAME"
  zone_id   = var.zone_id
  ttl       = 5
  records = [aws_lb.lb[0].dns_name]
}
# create load balancer
resource "aws_lb" "lb" {
  count              = var.lb_required ? 1 : 0
  name               = "${var.env}-${var.component}-lb"
  internal           = var.lb_internal_facing == "public" ? false : true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg[0].id]
  subnets            = var.lb_subnets
   tags = {
    Environment = "${var.env}-${var.component}-lb"
  }
}
# create target group
resource "aws_lb_target_group" "tg" {
  count              = var.lb_required ? 1 : 0
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
# target group attachment
resource "aws_lb_target_group_attachment" "tg_attachment" {
  count              = var.lb_required ? 1 : 0
  target_group_arn = aws_lb_target_group.tg[0].arn
  target_id        = aws_instance.instance.id
  port             = var.app_port
}
# redirect http to https
resource "aws_lb_listener" "frontend_http" {
  count              = var.lb_required && var.lb_internal_facing == "public" ? 1 : 0
  load_balancer_arn = aws_lb.lb[0].arn
  port              = var.app_port
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "frontend_https" {
  count              = var.lb_required && var.lb_internal_facing == "public" ? 1 : 0
  load_balancer_arn = aws_lb.lb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-1-2021-06"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
}
//create a listener
resource "aws_lb_listener" "backend-http" {
  count             = var.lb_required && var.lb_internal_facing != "public" ? 1 : 0
  load_balancer_arn = aws_lb.lb[0].arn
  port              = var.app_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
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
# create a load balancer security group
resource "aws_security_group" "lb_sg" {
  count       = var.lb_required ? 1 : 0
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



