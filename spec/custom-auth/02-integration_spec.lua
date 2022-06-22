local helpers = require "spec.helpers"


local PLUGIN_NAME = "custom-auth"


for _, strategy in helpers.all_strategies() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      local CLIENT_ID = "skoiy-client"
      local CLIENT_SECRET = "jlJBVW21q0wG1OrVrkj3Y5fsAeAIRDGz"
      local INTROSPECTION_ENDPOINT = "https://keycloak.kamino.tk/realms/skoiy/protocol/openid-connect/token/introspect"
      local AUTHORIZATION_ENDPOINT = "https://keycloak.kamino.tk/realms/skoiy/protocol/openid-connect/token"
    
      local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

      -- Inject a test route. No need to create a service, there is a default
      -- service which will echo the request.
      local route1 = bp.routes:insert({
        hosts = { "test1.com" },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {
          client_id = CLIENT_ID,
          client_secret = CLIENT_SECRET,
          introspection_endpoint = INTROSPECTION_ENDPOINT,
          authorization_endpoint = AUTHORIZATION_ENDPOINT
        },
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)



    describe("request", function()
      it("gets a 'hello-world' header", function()
        local r = client:get("/request", {
          headers = {
            host = "test1.com"
          }
        })
        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(401)
      end)
    end)

    describe("can introspect", function()
      it("gets a valid response", function()
        local access_token = "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJFQ3A2dnBjZkMtZHRpM0VsT0NzbkdFNGVkMzBYYkg3Z1dXVF9rQXR5NmE4In0.eyJleHAiOjE2NTU5MTc4NDEsImlhdCI6MTY1NTkxNDI0MSwianRpIjoiMjJiYzExZmUtNTAyMC00NjA2LTk1YjEtOGJmZmJlN2ViMDhmIiwiaXNzIjoiaHR0cHM6Ly9rZXljbG9hay5rYW1pbm8udGsvcmVhbG1zL3Nrb2l5IiwiYXVkIjoiYWNjb3VudCIsInN1YiI6IjFkOTQ5YWQ4LWM0NWYtNGVmOC1hMGFmLWMxY2Y4ODJlYTU3YiIsInR5cCI6IkJlYXJlciIsImF6cCI6InNrb2l5LWNsaWVudCIsInNlc3Npb25fc3RhdGUiOiJiODM5NGQwMi00M2EzLTQ2YjctYjMxYi00NjU3NjA2NGQ3MzYiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbIioiXSwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iLCJkZWZhdWx0LXJvbGVzLXNrb2l5Il19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSIsInNpZCI6ImI4Mzk0ZDAyLTQzYTMtNDZiNy1iMzFiLTQ2NTc2MDY0ZDczNiIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiSm9obiBEb2UiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJhZG1pbiIsImdpdmVuX25hbWUiOiJKb2huIiwiZmFtaWx5X25hbWUiOiJEb2UiLCJhZ2UiOjM2LCJlbWFpbCI6ImFkbWluQGdtYWlsLmNvbSJ9.HOcXNnrOWDKgx3QFxeGmIim52ac48cqRn_Sx3JKpZgtEUgA4qeFD4bsKpWYEDWLbcopkx3AmU7ikviZtaHyMzRyAgLSLZeZiwuiVLFkOebHrUjZAyMVnoM2Xvoz-ZTYn_X8ys9XNM3tuNTMmTi5Ud-MXvNQPwgK7NmrLuiueM7UpMYZHdafPt_-JTb1hc6CVYKFzV-P3keciANpxihWkTQIQuDK24wtT1wgpIPw87cJNKHAolmqE2jrhDPIAZncWEqklKOdFbyNj_fR3-Ba41THbDeqSEj4gimMFMVg5N4y1uPslGEGeMo4X-X2OQhRzjsSC1OyYBB01ggp2R5ODIQ"
        local r = client:get("/request", {
          headers = {
            host = "test1.com",
            Authorization = "Bearer " .. access_token
          }
        })

        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)
        assert.response(r).has.header("X-Userinfo")
      end)
    end)

  end)
end
