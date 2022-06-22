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
        local r = client:get("/request", {
          headers = {
            host = "test1.com",
            Authorization = "Bearer xyz"
          }
        })

        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)
        assert.response(r).has.header("X-Userinfo")
      end)
    end)

  end)
end
