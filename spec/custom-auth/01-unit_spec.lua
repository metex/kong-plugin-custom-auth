local PLUGIN_NAME = "custom-auth"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

  local CLIENT_ID = "skoiy-client"
  local CLIENT_SECRET = "jlJBVW21q0wG1OrVrkj3Y5fsAeAIRDGz"
  local INTROSPECTION_ENDPOINT = "https://keycloak.kamino.tk/realms/skoiy/protocol/openid-connect/introspect"
  local AUTHORIZATION_ENDPOINT = "https://keycloak.kamino.tk/realms/skoiy/protocol/openid-connect/token"
  
  it("accepts distinct request_header and response_header", function()
    local ok, err = validate({
        request_header = "My-Request-Header",
        response_header = "Your-Response",
        client_id = CLIENT_ID,
        client_secret = CLIENT_SECRET,
        introspection_endpoint = INTROSPECTION_ENDPOINT,
        authorization_endpoint = AUTHORIZATION_ENDPOINT
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)


  it("does not accept identical request_header and response_header", function()
    local ok, err = validate({
        request_header = "they-are-the-same",
        response_header = "they-are-the-same",
        client_id = CLIENT_ID,
        client_secret = CLIENT_SECRET,
        introspection_endpoint = INTROSPECTION_ENDPOINT,
        authorization_endpoint = AUTHORIZATION_ENDPOINT
      })

    assert.is_same({
      ["config"] = {
        ["@entity"] = {
          [1] = "values of these fields must be distinct: 'request_header', 'response_header'"
        }
      }
    }, err)
    assert.is_falsy(ok)
  end)

  it("provides a default response_header", function()
    local ok, err = validate({
     request_header = "My-Request-Header",
     response_header = nil,
     client_id = CLIENT_ID,
     client_secret = CLIENT_SECRET,
     introspection_endpoint = INTROSPECTION_ENDPOINT,
     authorization_endpoint = AUTHORIZATION_ENDPOINT
    })
   assert.is_nil(err)
   assert.is_truthy(ok)
   end)

   it("accepts introspection_endpoint config", function()
    local ok, err = validate({
      client_id = CLIENT_ID,
      client_secret = CLIENT_SECRET,
      introspection_endpoint = INTROSPECTION_ENDPOINT,
      authorization_endpoint = AUTHORIZATION_ENDPOINT
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

end)
