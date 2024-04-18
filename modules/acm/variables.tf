variable "domain_name" {
  type = string
}

variable "public_dns_verify" {
  type = list(object({
    name = string
    fqdn = string
  }))
}