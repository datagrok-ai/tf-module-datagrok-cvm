data "aws_mq_broker" "name" {
  broker_name = var.rabbitmq_name
}


resource "aws_ssm_parameter" "grok_parameters" {
  name = "/datagrok/GROK_PARAMETERS_CVM"
  type = "String" # Можно использовать "String", но "SecureString" лучше для паролей
  value = jsonencode(
    {
      jupyterToken : jsondecode(data.aws_secretsmanager_secret_version.jkg_secret.secret_string)["token"]
      capabilities : ["jupyter"]
      isolatesCount: var.jkgIsolatesCount,
      queuePluginSettings = {
        amqpHost     = split(":", split("://", data.aws_mq_broker.name.instances[0].endpoints[0])[1])[0]
        amqpPassword = var.rabbitmq_password
        amqpPort     = var.amqpPort
        amqpUser     = var.rabbitmq_username
        tls = var.amqpTLS
        pipeHost     = "grok_pipe.datagrok.${split("-",var.name)[0]}.${var.environment}.internal:3000"
        pipeKey      = var.pipeKey
        maxConcurrentCalls = 4

      }
  })
  overwrite = true
  tags = {
    Name        = "GROK_PARAMETERS"
    Environment = "production"
  }
}
