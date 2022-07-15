local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "custom-auth"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          -- a standard defined field (typedef), with some customizations
          { request_header = typedefs.header_name {
              required = true,
              default = "Hello-World" } },
          { response_header = typedefs.header_name {
              required = true,
              default = "Version" } },
          { ttl = { -- self defined field
              type = "integer",
              default = 600,
              required = true,
              gt = 0, }}, -- adding a constraint for the value
          { realm = typedefs.header_name {
                required = true,
                default = "master" } },
          { client_id = { -- self defined field
              type = "string",              
              required = true}},
          { client_secret = { -- self defined field
              type = "string",              
              required = true}},
          { auth_host = { -- self defined field
              type = "string",              
              required = true}},
          { introspection_endpoint = typedefs.url({ required = true }) },
          { authorization_endpoint = typedefs.url({ required = true }) },
          { token_header = typedefs.header_name { default = "Authorization", required = true }, },
          { user_info_header_name = typedefs.header_name { default = "X-Userinfo", required = true }, },
          { ssl_verify = { -- self defined field
              type = "boolean",
              default = false,
              required = true}},
          { timeout = { -- self defined field
              type = "integer",
              default = 3000,
              required = true }}
        },
        entity_checks = {
          -- add some validation rules across fields
          -- the following is silly because it is always true, since they are both required
          { at_least_one_of = { "request_header", "response_header" }, },
          -- We specify that both header-names cannot be the same
          { distinct = { "request_header", "response_header"} },
        },
      },
    },
  },
}

return schema
