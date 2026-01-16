################################################################################
# Lambda Layer for Python Dependencies
################################################################################

resource "aws_lambda_layer_version" "python_dependencies" {
  count = var.lambda_layer_arn == "" && var.lambda_layer_zip_path != "" ? 1 : 0

  layer_name          = "${var.prefix}-python-dependencies"
  filename            = var.lambda_layer_zip_path
  source_code_hash    = filebase64sha256(var.lambda_layer_zip_path)
  compatible_runtimes = [local.lambda_runtime]

  description = "Python dependencies (PyJWT, boto3, cryptography) for GitHub runner Lambda functions"
}

data "aws_lambda_layer_version" "python_dependencies" {
  count = var.lambda_layer_arn != "" ? 1 : 0

  layer_name = split(":", var.lambda_layer_arn)[6]
  version    = split(":", var.lambda_layer_arn)[7]
}

locals {
  lambda_layers = var.lambda_layer_arn != "" ? [var.lambda_layer_arn] : (var.lambda_layer_zip_path != "" && length(aws_lambda_layer_version.python_dependencies) > 0 ? [aws_lambda_layer_version.python_dependencies[0].arn] : [])
}
