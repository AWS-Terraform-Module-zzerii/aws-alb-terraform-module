variable "account_id" {
    type    = string
}
variable "current_region" {
  type      = string
}

variable "current_id" {
  type      = string
}
variable "region" {
    type    = string
}

variable "prefix" {
    type    = string
}

variable "vpc_id" {
    type    = string
}

# ALB
variable "alb_name" {
    type    = string
}
variable "internal" {
    type    = bool
}
variable "security_groups" {
    type    = list(string)
}
variable "subnets" {
    type    = list(string)
}
variable "enable_deletion_protection" {
    type    = bool
}

# # Target Group
variable "tg_list" {
    type = map(any)
}

variable "add_target_list" {
    type = map(any)  
}

#Listener
variable "forward_listerner" {
    type = map(any)
}

variable "redirect_listerner" {
    type = map(any)
}

variable "tags" {
    type = map(string)
}

variable "bucket_name" {
  type      = string
  default = "dumy"
}

variable "bucket_prefix" {
  type      = string
  default = "dumy"
}

variable "bucket_access_log_enabled" {
    type = bool
    default = false
}

