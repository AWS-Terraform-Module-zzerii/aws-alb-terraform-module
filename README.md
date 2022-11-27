# terraform-aws-module-alb

- AWS ALB를 생성하는 공통 모듈

## Usage

### `terraform.tfvars`

- 모든 변수는 적절하게 변경하여 사용

```plaintext
account_id                      = "123455667" # 아이디 변경 필수
region                          = "ap-northeast-2"
prefix                          = "dev"

vpc_name                        = "eks-test-vpc"

# alb
alb_name                        = "terraform-alb"
internal                        = false    # true == 내부 LB

security_groups_filters         = {
  "Name" = ["control-plane"]       # ["sg-01", "sg-02", ....]
}


subnet_filters                      = {
  "Name" = ["eks-test-vpc-subnet-pub-2a", "eks-test-vpc-subnet-pub-2c"]
}
enable_deletion_protection      	= true            # 삭제 방지 활성화

#Target Group

tg_list = {
    web-tg = {
            #target_type                    = ""       # default==instance  # ip/alb 일 경우 모듈 수정 필요

            connection_termination          = false     # 등록 취소 시간 초과 끝날 때 연결 종료 여부
            deregistration_delay            = 300       # 등록 취소 대상의 상태를 미사용으로 변경하기 전에 Elastic Load Balancing이 대기하는 시간

            tg_port                         = 80
            tg_protocol                     = "HTTP"
            protocol_version                = "HTTP1"   # HTTP/HTTPS 일 경우 적용  # HTTP1/HTTP2/GRPC

            load_balancing_algorithm_type   = "round_robin"   #round_robin/least_outstanding_requests

            #stickiness
            stickiness_enabled              = true
            stickiness_type                 = "lb_cookie"       # alb => lb_cookie/app_cookie

            cookie_duration                 = 10                #type==lb_cookie 일 경우 사용
            # cookie_name                     = ""                #type==app_cookie 일 경우 사용

            #health check
            interval                        = 30     # health check 초 range: 5-300  default: 30  
            path                            = "/"    # health check 경로  HTTP/HTTPS에만 적용
            protocol                        = "HTTP"
            matcher                         = 200    # HTTP => 200-299  GRPC => 0-99
            port                            = "traffic-port"     #"traffic-port" or 1-65535 
            healthy_threshold               = 3      # health check success num
            unhealthy_threshold             = 3      # nlb는 healthy_threshold와 값이 같아야함
    }, 
    was-tg = {
            #target_type                    = ""

            connection_termination          = false
            deregistration_delay            = 300

            tg_port                         = 80
            tg_protocol                     = "HTTP"
            protocol_version                = "HTTP1"

            load_balancing_algorithm_type   = "round_robin"

            #stickiness
            stickiness_enabled              = true
            stickiness_type                 = "lb_cookie"

            cookie_duration                 = 10
            cookie_name                     = ""

            #health check
            interval                        = 30
            path                            = "/"
            protocol                        = "HTTP"
            matcher                         = 200
            port                            = "traffic-port"
            healthy_threshold               = 3
            unhealthy_threshold             = 3
    },
}

# target_group_attachment
tag_name        = "Name"

# ALB Access Logs
bucket_name                 = "kcl-test"
bucket_prefix               = "webwas_alb"
bucket_access_log_enabled   = true

# target_group_attachment   locals.tf 에서 설정합니다.
# attach 할 인스턴스들을 data.tf에서 정의합니다.

# redirect listener 와 forward listener 를 따로 만들었습니다.



# forward listener는 locals 에서 정의 합니다.


redirect_listerner   = {
               http80-https443 ={
                                    listener_port       = 81
                                    listener_protocol   = "HTTP"       #TCP/TLS/UDP/TCP_UDP
                                    type                = "redirect"
                                    listener_tg         = "web-tg"


                                    #redirect
                                    redirect_port       = 443
                                    redirect_protocol   = "HTTPS"
                                    status_code         = "HTTP_301"
                                },
                    }

tags = {
    "CreatedByTerraform"        = "true"
    "TerraformModuleName"       = "terraform-aws-module-alb"
    "TerraformModuleVersion"    = "v1.0.3"
}
```

------

### `main.tf`

```plaintext
module "alb" {
    source = "git::https://github.com/aws-alb-module.git?ref=v1.0.3"

    current_id                      = data.aws_caller_identity.current.account_id
    current_region                  = data.aws_region.current.name

    account_id                      = var.account_id
    region                          = var.region
    prefix                          = var.prefix

    vpc_id                          = data.aws_vpc.vpc.id

    # alb
    alb_name                        = var.alb_name
    internal                        = var.internal
    security_groups                 = data.aws_security_groups.sg_list.ids
    subnets                         = data.aws_subnets.subnet_list.ids
    enable_deletion_protection      = var.enable_deletion_protection

    bucket_name                     = var.bucket_name
    bucket_prefix                   = var.bucket_prefix
    bucket_access_log_enabled       = var.bucket_access_log_enabled

   # target group
    tg_list                         = var.tg_list

   # target_attachment
    add_target_list                 = local.add_target_list

    # listener 
    forward_listerner               = local.forward_listerner
    redirect_listerner              = var.redirect_listerner
    
    tags                            = var.tags
} 
```

------

### `provider.tf`

```plaintext
provider "aws" {
   region = var.region
}
```

------

### `terraform.tf`

```plaintext
terraform {
  required_version = ">= 1.1.2"

  required_providers {
    aws = {
      source    = "hashicorp/aws"
      version   = "~> 3.39"
    }
  }

  backend "s3" {
    bucket         = "-tf-state-backend"
    key            = "012345678912/common/alb/terraform.state"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

------

### `data.tf`

```plaintext
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
    filter {
        name = "tag:Name"
        values = ["${var.vpc_name}"]
    }
}

data "aws_security_groups" "sg_list" {
  dynamic "filter" {
    for_each = var.security_groups_filters
    iterator = tag
    content {
      name      = "tag:${tag.key}"
      values    = "${tag.value}"
    }
  }
}

data "aws_subnets" "subnet_list" {
  dynamic "filter" {
    for_each = var.subnet_filters
    iterator = tag
    content {
      name      = "tag:${tag.key}"
      values    = "${tag.value}"
    }
  }
}

# 사용 할 인스턴스 만큼 data source를 만들어 줍니다.
data "aws_instance" "test-2a" {
    filter {
        name        = "tag:${var.tag_name}"
        values      = ["test-2a"]
    }
}

data "aws_instance" "test-2c" {
    filter {
        name        = "tag:${var.tag_name}"
        values      = ["test-2c"]
    }
}

# 사용할 SSL 인증서 도메인 만큼 data source를 만들어 줍니다.
data "aws_acm_certificate" "zzerii-site" {
    domain      = "zzerii.site"
    statuses    = ["ISSUED"]
}

```

------

### `locals.tf`

```
locals {

    # target_name = data.aws_instance.[data.tf의 data source 이름].id
    # Key값은 중복 될 수 없다
    add_target_list = {
        web-tg-test-2a = {
                            target_name       = "${data.aws_instance.test-2a.id}"
                            target_port       = 80
                            target_group      = "web-tg"
                        },
        web-tg-test-2c = {
                            target_name       = "${data.aws_instance.test-2c.id}"
                            target_port       = 80
                            target_group      = "web-tg"
                        },
        was-tg-test-2a = {
                            target_name       = "${data.aws_instance.test-2a.id}"
                            target_port       = 80
                            target_group      = "was-tg"
                        },
        was-tg-test-2c = {
                            target_name       = "${data.aws_instance.test-2c.id}"
                            target_port       = 80
                            target_group      = "was-tg"
                        },
    }
}

locals {
  forward_listerner   = {
        http-80 = {
                    listener_port     = 80
                    listener_protocol = "HTTP"       #TCP/TLS/UDP/TCP_UDP
                    type              = "forward"    
                    listener_tg       = "web-tg"
                    certificate_arn   = null
                },
        httpa-443 = {
                    listener_port     = 443
                    listener_protocol = "HTTPS"
                    type              = "forward"
                    listener_tg       = "web-tg"
                    certificate_arn   = "${data.aws_acm_certificate.zzerii-site.arn}"
                },
    }
}
```

### `variables.tf`

```plaintext
variable "account_id" {
    type    = string
    default = ""
}

variable "region" {
    type    = string
    default = ""
}

variable "prefix" {
    type    = string
    default = ""
}

variable "vpc_name" {
    type    = string
    default = ""
}

#ALB
variable "alb_name" {
    type = string
    default = ""
}
variable "internal" {
    type = bool
    default = false
}
variable "security_groups_filters" {
    type = map(list(string))
#    default = []
}
variable "subnet_filters" {
    type    = map(list(string))
#    default = []
}
variable "enable_deletion_protection" {
    type = bool
    default = true
}

# #TargetGroup
variable "tg_list" {
    type = map(any)
    default = {}
}

variable "tag_name" {
  type = string
  default = ""
}

variable "add_target_list" {
  type = map(any)
  default = {}
}

#Listener
variable "forward_listerner" {
    type = map(any)
    default = {}
}

variable "redirect_listerner" {
    type = map(any)
    default = {}
}

variable "bucket_name" {
    type = string
    default = ""
}

variable "bucket_prefix" {
    type = string
    default = ""
}

variable "bucket_access_log_enabled" {
    type = bool
    default = false
}

variable "tags" {
    type = map(string)
    default = {}
}
```

------

### `outputs.tf`

```plaintext
output "result" {
    value = module.alb
}
```

## 실행방법

```plaintext
terraform init -get=true -upgrade -reconfigure
terraform validate (option)
terraform plan -var-file=terraform.tfvars -refresh=false -out=planfile
terraform apply planfile
```

- "Objects have changed outside of Terraform" 때문에 `-refresh=false`를 사용
- 실제 UI에서 리소스 변경이 없어보이는 것과 low-level Terraform에서 Object 변경을 감지하는 것에 차이가 있는 것 같음, 다음 링크 참고
  - https://github.com/hashicorp/terraform/issues/28776
- 위 이슈로 변경을 감지하고 리소스를 삭제하는 케이스가 발생 할 수 있음