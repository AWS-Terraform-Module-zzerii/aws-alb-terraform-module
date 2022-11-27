resource "null_resource" "validate_account" {
  count = var.current_id == var.account_id ? 0 : "Please check that you are using the AWS account"
}

resource "null_resource" "validate_module_name" {
  count = local.module_name == var.tags["TerraformModuleName"] ? 0 : "Please check that you are using the Terraform module"
}

resource "null_resource" "validate_module_version" {
  count = local.module_version == var.tags["TerraformModuleVersion"] ? 0 : "Please check that you are using the Terraform module"
}

resource "aws_alb" "alb" {
    name                       = "${var.prefix}-${var.alb_name}"
    internal                   = var.internal
    security_groups            = var.security_groups
    subnets                    = var.subnets
    enable_deletion_protection = var.enable_deletion_protection

    access_logs {
      bucket  = var.bucket_access_log_enabled ? var.bucket_name : "dumy"
      prefix  = var.bucket_access_log_enabled ? var.bucket_prefix : "dumy"
      enabled = var.bucket_access_log_enabled
    }

    tags = merge(var.tags, tomap({ "Name" = "${var.prefix}-${var.alb_name}" }))
}

resource "aws_alb_target_group" "alb_target_group" {
  for_each                            = var.tg_list

  name                                = "${var.prefix}-${var.alb_name}-${each.key}"
  connection_termination              = each.value.connection_termination
  deregistration_delay                = each.value.deregistration_delay

  port                                = each.value.tg_port
  protocol                            = each.value.tg_protocol

  protocol_version                    = each.value.protocol_version
  
  vpc_id                              = var.vpc_id
  
  load_balancing_algorithm_type       = each.value.load_balancing_algorithm_type

  stickiness {
    enabled               = each.value.stickiness_enabled
    type                  = each.value.stickiness_type
    cookie_duration       = each.value.cookie_duration
    # cookie_name           = each.value.cookie_name  # app cookie 사용 시 활성화
  }

  health_check {
    interval            = each.value.interval
    path                = each.value.path  # health check 경로  HTTP/HTTPS에만 적용
    protocol            = each.value.protocol
    matcher             = each.value.matcher
    port                = each.value.port
    healthy_threshold   = each.value.healthy_threshold
    unhealthy_threshold = each.value.unhealthy_threshold
  }
    tags = merge(var.tags, tomap({ "Name" = "${var.prefix}-${var.alb_name}-${each.key}" }))    
}


resource "aws_alb_target_group_attachment" "add_target" {
  for_each          = var.add_target_list

  target_group_arn  = aws_alb_target_group.alb_target_group[each.value.target_group].arn
  port              = each.value.target_port
  target_id         = each.value.target_name
}


resource "aws_alb_listener" "listener_forward" {
  for_each          = var.forward_listerner

  load_balancer_arn = aws_alb.alb.arn
  port              = each.value.listener_port
  protocol          = each.value.listener_protocol
  
  certificate_arn   = each.value.certificate_arn
  
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group["${each.value.listener_tg}"].arn
    type             = each.value.type
  }
}


resource "aws_alb_listener" "listener_redirect" {
  for_each          = var.redirect_listerner

  load_balancer_arn = aws_alb.alb.arn
  port              = each.value.listener_port
  protocol          = each.value.listener_protocol
  
  default_action {
    target_group_arn  = aws_alb_target_group.alb_target_group["${each.value.listener_tg}"].arn
    type              = each.value.type
    redirect {
      port            = each.value.redirect_port
      protocol        = each.value.redirect_protocol
      status_code     = each.value.status_code
    }
  }
}