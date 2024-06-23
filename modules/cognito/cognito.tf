#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para Cognito
#--------------------------------------------------------------
variable "generate_secret"                { default = true }
variable "name"                           { default = "cognito" }
variable "tags"                           { }
variable "clients"                        { }
variable "resources"                      { default = [] }
variable "identity_providers"             { default = [] }
variable "schemas"                        { default = [] }
variable "string_schemas"                 { default = [] }
variable "number_schemas"                 { default = [] }


locals {
  created_depends = length(var.identity_providers) > 0 ? true : false
}
resource "aws_cognito_user_pool" "pool" {
  name = var.name
  account_recovery_setting {
      recovery_mechanism {
    
        name     = "verified_email"
        priority = 1
      }
  }
  
  # schema
  dynamic "schema" {
    for_each = var.schemas == null ? [] : var.schemas
    content {
      attribute_data_type      = lookup(schema.value, "attribute_data_type")
      developer_only_attribute = lookup(schema.value, "developer_only_attribute")
      mutable                  = lookup(schema.value, "mutable")
      name                     = lookup(schema.value, "name")
      required                 = lookup(schema.value, "required")
    }
  }

  # schema (String)
  dynamic "schema" {
    for_each = var.string_schemas == null ? [] : var.string_schemas
    content {
      attribute_data_type      = lookup(schema.value, "attribute_data_type")
      developer_only_attribute = lookup(schema.value, "developer_only_attribute")
      mutable                  = lookup(schema.value, "mutable")
      name                     = lookup(schema.value, "name")
      required                 = lookup(schema.value, "required")

      # string_attribute_constraints
      dynamic "string_attribute_constraints" {
        for_each = length(lookup(schema.value, "string_attribute_constraints")) == 0 ? [] : [lookup(schema.value, "string_attribute_constraints", {})]
        content {
          min_length = lookup(string_attribute_constraints.value, "min_length", 0)
          max_length = lookup(string_attribute_constraints.value, "max_length", 0)
        }
      }
    }
  }

  # schema (Number)
  dynamic "schema" {
    for_each = var.number_schemas == null ? [] : var.number_schemas
    content {
      attribute_data_type      = lookup(schema.value, "attribute_data_type")
      developer_only_attribute = lookup(schema.value, "developer_only_attribute")
      mutable                  = lookup(schema.value, "mutable")
      name                     = lookup(schema.value, "name")
      required                 = lookup(schema.value, "required")

      # number_attribute_constraints
      dynamic "number_attribute_constraints" {
        for_each = length(lookup(schema.value, "number_attribute_constraints")) == 0 ? [] : [lookup(schema.value, "number_attribute_constraints", {})]
        content {
          min_value = lookup(number_attribute_constraints.value, "min_value", 0)
          max_value = lookup(number_attribute_constraints.value, "max_value", 0)
        }
      }
    }
  }

  tags  = merge(
    var.tags,
    { Name = "${var.name}" },
  )
}

resource "aws_cognito_identity_provider" "providers" {
  for_each = {for identity_provider in var.identity_providers:  identity_provider.provider_name => identity_provider}
  user_pool_id  = aws_cognito_user_pool.pool.id  
  provider_type     = each.value.provider_type
  provider_name     = each.value.provider_name
  provider_details  = each.value.provider_details
  attribute_mapping = each.value.attribute_mapping
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.name
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_resource_server" "resource" {
  count = length(var.resources)
  identifier = lookup(element(var.resources, count.index), "identifier")
  name       = lookup(element(var.resources, count.index), "name")

  dynamic "scope" {
    for_each = lookup(element(var.resources, count.index), "scopes")
    content {
        scope_name        = scope.value.scope_name
        scope_description = scope.value.scope_description
    }
  }

  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "aws_cognito_user_pool_client" "client" {
  count = ((length(var.clients) > 0) && local.created_depends) ? 1 : 0
  name  = lookup(element(var.clients, count.index), "name")
  generate_secret     = var.generate_secret
  
  supported_identity_providers = lookup(element(var.clients, count.index), "supported_identity_providers", "COGNITO")
  allowed_oauth_flows = lookup(element(var.clients, count.index), "allowed_oauth_flows")
  
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = lookup(element(var.clients, count.index), "allowed_oauth_scopes")

  user_pool_id = aws_cognito_user_pool.pool.id

  explicit_auth_flows  =  lookup(element(var.clients, count.index), "explicit_auth_flows", null)
  callback_urls =  lookup(element(var.clients, count.index), "callback_urls", null)
  default_redirect_uri =  lookup(element(var.clients, count.index), "default_redirect_uri", null)
  logout_urls = lookup(element(var.clients, count.index), "logout_urls", null)
  prevent_user_existence_errors  = lookup(element(var.clients, count.index), "prevent_user_existence_errors") 

  access_token_validity                = lookup(element(var.clients, count.index), "access_token_validity", null)
  id_token_validity                    = lookup(element(var.clients, count.index), "id_token_validity", null)
  refresh_token_validity               = lookup(element(var.clients, count.index), "refresh_token_validity", null)

    # token_validity_units
  dynamic "token_validity_units" {
    for_each = length(lookup(element(var.clients, count.index), "token_validity_units", {})) == 0 ? [] : [lookup(element(var.clients, count.index), "token_validity_units")]
    content {
      access_token  = lookup(token_validity_units.value, "access_token", null)
      id_token      = lookup(token_validity_units.value, "id_token", null)
      refresh_token = lookup(token_validity_units.value, "refresh_token", null)
    }
  }

  depends_on = [
    aws_cognito_identity_provider.providers,
  ]
}

resource "aws_cognito_user_pool_client" "client_without_idp" {
  count = !local.created_depends ? 1 : 0
  name  = lookup(element(var.clients, count.index), "name")
  generate_secret     = var.generate_secret
  
  supported_identity_providers = lookup(element(var.clients, count.index), "supported_identity_providers", "COGNITO")
  allowed_oauth_flows = lookup(element(var.clients, count.index), "allowed_oauth_flows")

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = lookup(element(var.clients, count.index), "allowed_oauth_scopes")

  user_pool_id = aws_cognito_user_pool.pool.id

  explicit_auth_flows  =  lookup(element(var.clients, count.index), "explicit_auth_flows", null)
  callback_urls =  lookup(element(var.clients, count.index), "callback_urls", null)
  default_redirect_uri =  lookup(element(var.clients, count.index), "default_redirect_uri", null)
  logout_urls = lookup(element(var.clients, count.index), "logout_urls", null)
  prevent_user_existence_errors  = lookup(element(var.clients, count.index), "prevent_user_existence_errors") 

  access_token_validity                = lookup(element(var.clients, count.index), "access_token_validity", null)
  id_token_validity                    = lookup(element(var.clients, count.index), "id_token_validity", null)
  refresh_token_validity               = lookup(element(var.clients, count.index), "refresh_token_validity", null)

    # token_validity_units
  dynamic "token_validity_units" {
    for_each = length(lookup(element(var.clients, count.index), "token_validity_units", {})) == 0 ? [] : [lookup(element(var.clients, count.index), "token_validity_units")]
    content {
      access_token  = lookup(token_validity_units.value, "access_token", null)
      id_token      = lookup(token_validity_units.value, "id_token", null)
      refresh_token = lookup(token_validity_units.value, "refresh_token", null)
    }
  }
}


output "cognito_arn" { value = "${aws_cognito_user_pool.pool.arn}" }
output "client_secret" { value = "${aws_cognito_user_pool_client.client.*.client_secret}" }
output "client_id" { value = "${aws_cognito_user_pool_client.client.*.id}" }
output "scope_identifiers" { value = "${aws_cognito_resource_server.resource.*.scope_identifiers}" }
output "cognito_endpoint" { value = aws_cognito_user_pool.pool.endpoint }
output "client_secret_without_idp" { value = "${aws_cognito_user_pool_client.client_without_idp.*.client_secret}" }
output "client_id_without_idp" { value = "${aws_cognito_user_pool_client.client_without_idp.*.id}" }
