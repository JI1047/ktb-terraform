variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "static_bucket_name" {
  type = string
}

variable "ssr_origin_domain" {
  type = string
}

variable "ssr_origin_protocol_policy" {
  type    = string
  default = "http-only"

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.ssr_origin_protocol_policy)
    error_message = "ssr_origin_protocol_policy must be one of: http-only, https-only, match-viewer."
  }
}

variable "aliases" {
  type    = list(string)
  default = []
}

variable "acm_cert_arn" {
  type    = string
  default = null
}
