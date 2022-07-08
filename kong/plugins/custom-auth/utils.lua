local http = require "resty.http"
local cjson = require "cjson"
local M = {}

function M.introspect_access_token(conf, access_token)
    local client_id = conf.client_id
    local client_secret = conf.client_secret

    local httpc = http:new()
    -- step 1: validate the token
    local res, err = httpc:request_uri(conf.introspection_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            -- ["Authorization"] = "Bearer " .. access_token 
        },
        body = "token=" .. access_token .. "&client_id=" .. client_id .. "&client_secret=" .. client_secret,
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
    kong.log.debug("Response ")
    kong.log.inspect(data)
    local active = data["active"]
    if active == false then
        kong.log.debug("NotActive ")
        return kong.response.exit(401)
    end

    kong.log.debug("Inject ")
    M.injectUser(data)

    kong.log.debug("Injected ")
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
return M