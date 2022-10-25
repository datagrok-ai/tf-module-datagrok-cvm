resource "random_pet" "this" {
  count  = var.enable_bucket_logging && !try(length(var.log_bucket) > 0, false) ? 1 : 0
  length = 2
}
module "log_bucket" {
  create_bucket = var.enable_bucket_logging && !try(length(var.log_bucket) > 0, false)
  source        = "registry.terraform.io/terraform-aws-modules/s3-bucket/aws"
  version       = "~> 3.3.0"

  bucket        = "logs-${try(random_pet.this[0].id, "")}"
  acl           = "log-delivery-write"
  force_destroy = true

  attach_elb_log_delivery_policy        = true
  attach_lb_log_delivery_policy         = true
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = [
    {
      id      = "expiration_rule"
      enabled = true
      expiration = {
        days = 7
      }
    }
  ]
  tags = local.tags
}
