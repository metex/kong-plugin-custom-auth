local http = require "resty.http"
local cjson = require "cjson"
-- alternatively: local lrucache = require "resty.lrucache.pureffi"
local lrucache = require "resty.lrucache"

local M = {}

-- we need to initialize the cache on the lua module level so that
-- it can be shared by all the requests served by each nginx worker process:
local c, err = lrucache.new(200)  -- allow up to 200 items in the cache
if not c then
    error("failed to create the cache: " .. (err or "unknown"))
end

local function parseFilters(csvFilters)
  local filters = {}
  if (not (csvFilters == nil)) then
    for pattern in string.gmatch(csvFilters, "[^,]+") do
      table.insert(filters, pattern)
    end
  end
  return filters
end

function M.get_options(config, ngx)
  return {
    client_id = config.client_id,
    client_secret = config.client_secret,
    --discovery = config.discovery,
    introspection_endpoint = config.introspection_endpoint,
    -- timeout = config.timeout,
    -- introspection_endpoint_auth_method = config.introspection_endpoint_auth_method,
    -- bearer_only = config.bearer_only,
    -- realm = config.realm,
    -- redirect_uri_path = config.redirect_uri_path or M.get_redirect_uri_path(ngx),
    -- scope = config.scope,
    -- response_type = config.response_type,
    -- ssl_verify = config.ssl_verify,
    -- token_endpoint_auth_method = config.token_endpoint_auth_method,
    -- recovery_page_path = config.recovery_page_path,
    -- filters = parseFilters(config.filters),
    -- logout_path = config.logout_path,
    -- redirect_after_logout_uri = config.redirect_after_logout_uri,
  }
end

function M.handle(conf)
  local body, err, mimetype = kong.request.get_body("application/x-www-form-urlencoded")
  local client_id = conf.client_id
  local client_secret = conf.client_secret
  local auth_host = conf.auth_host

  local username = body.username
  local password = body.password
  local grant_type = "password"
  local scope = "openid profile email"

  local body = "username=" .. username .. "&password=" .. password .. "&client_id=" .. client_id .. "&client_secret=" .. client_secret .. "&grant_type=" .. grant_type .. "&scope=" .. scope
  local httpc = http:new()
  -- step 1: validate the token
  local res, err = httpc:request_uri(conf.authorization_endpoint, {
      method = "POST",
      ssl_verify = false,
      headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded",
          ["Host"] = auth_host
      },
      body = body,
  })

  kong.log.inspect(res)
  if not res then
    kong.log.err("failed to call token endpoint: ",err)
    return kong.response.exit(500)
  end

  if res.status ~= 200 then
    kong.log.err("authorization endpoint responded with status: ",res.status)
    return kong.response.exit(res.status)
  end
  
  c:set("dog", "32")
  local dog = c:get("dog")
  kong.log.debug("#############dog|" .. dog .. "|")
  local data = cjson.decode(res.body)
  --kong.log.debug(data)
  local headers = {
    ["Content-Type"] = "application/json",
  }

  M.injectIdTenant("1")
  kong.response.exit(200, data, headers)
end

function M.introspect_access_token(conf, access_token)
  local client_id = conf.client_id
  local client_secret = conf.client_secret
  local auth_host = conf.auth_host

  local body = "token=" .. access_token .. "&client_id=" .. client_id .. "&client_secret=" .. client_secret
  local httpc = http:new()
  -- step 1: validate the token
  local res, err = httpc:request_uri(conf.introspection_endpoint, {
      method = "POST",
      ssl_verify = false,
      headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded",
          ["Host"] = auth_host
          -- ["Authorization"] = "Bearer " .. access_token 
      },
      body = body,
  })

  if not res then
      kong.log.err("failed to call introspection endpoint: ",err)
      return kong.response.exit(500)
  end

  if res.status ~= 200 then
      kong.log.err("introspection endpoint responded with status: ",res.status)
      return kong.response.exit(res.status)
  end

  -- step 2: decode the returned json and validate if the access token is active
  local data = cjson.decode(res.body)
  local active = data["active"]
  if active == false then      
      return kong.response.exit(401)
  end

  M.injectUser(data)

  -- Inject the header X-Userinfo in the upstream server request
  kong.service.request.set_header(conf.user_info_header_name, ngx.encode_base64(cjson.encode(data)))

  return true -- all is well
end

function M.injectIDToken(idToken)
  local tokenStr = cjson.encode(idToken)
  -- ngx.req.set_header("X-ID-Token", ngx.encode_base64(tokenStr))
end

function M.injectUser(user)
  local tmp_user = user
  tmp_user.id = user.sub
  tmp_user.username = user.preferred_username
  -- ngx.ctx.authenticated_credential = tmp_user
  local userinfo = cjson.encode(user)
  -- ngx.req.set_header("X-Userinfo", ngx.encode_base64(userinfo))
  kong.response.set_header("X-Userinfo", ngx.encode_base64(userinfo))
end

function M.injectAccessToken(accessToken)
  ngx.req.set_header("X-Access-Token", accessToken)
end

function M.injectIdTenant(id)
  kong.response.set_header("X-IdTenant", id)  
end

return M