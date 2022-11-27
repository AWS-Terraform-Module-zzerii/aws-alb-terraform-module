output "alb_id" {
    value = aws_alb.alb.id
}

output "alb_dns_name" {
    value = aws_alb.alb.dns_name
}

output "alb_tg_name" {
    value = {for k, v in aws_alb_target_group.alb_target_group: k => v.arn}
}

output "alb_tg_id" {
    value = {for k, v in aws_alb_target_group.alb_target_group: k => v.id}
}

output "alb_tg_port" {
    value = {for k, v in aws_alb_target_group.alb_target_group: k => v.port}
}


output "alb_listener_arn" {
    value = {for k, v in aws_alb_listener.listener_forward: k => v.arn}
}

output "alb_listener_id" {
    value = {for k, v in aws_alb_listener.listener_forward: k => v.id}
}

output "alb_listener_port" {
    value = {for k, v in aws_alb_listener.listener_forward: k => v.port}
}

output "alb_listener_protocol" {
    value = {for k, v in aws_alb_listener.listener_forward: k => v.protocol}
}