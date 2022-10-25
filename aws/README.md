## Usage

```hcl
module "datagrok_cvm" {
  # We recommend to specify an exact tag as ref argument
  source = "git@github.com:datagrok-ai/tf-module-datagrok-cvm.git//aws?ref=main"

  name                = "datagrok"
  environment         = "example"
  domain_name         = "datagrok.example"
  docker_hub_user     = "exampleUser"
  docker_hub_password = "examplePassword"
}
```
