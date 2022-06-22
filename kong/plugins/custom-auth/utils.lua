local http = require "resty.http"
local cjson = require "cjson"
local M = {}

function M.introspect_access_token(conf, access_token)
    local token = "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJFQ3A2dnBjZkMtZHRpM0VsT0NzbkdFNGVkMzBYYkg3Z1dXVF9rQXR5NmE4In0.eyJleHAiOjE2NTU5MDA4MTUsImlhdCI6MTY1NTg5NzIxNSwianRpIjoiZWM2M2ZmNzAtMWQ4ZC00NGRlLWJkNmEtMmJmMGFmYTZmYzdjIiwiaXNzIjoiaHR0cHM6Ly9rZXljbG9hay5rYW1pbm8udGsvcmVhbG1zL3Nrb2l5IiwiYXVkIjoiYWNjb3VudCIsInN1YiI6IjFkOTQ5YWQ4LWM0NWYtNGVmOC1hMGFmLWMxY2Y4ODJlYTU3YiIsInR5cCI6IkJlYXJlciIsImF6cCI6InNrb2l5LWNsaWVudCIsInNlc3Npb25fc3RhdGUiOiIwZTY2YTI1MC02MTdlLTRiMzgtODQxOS0zODVhNjFlOTRmNzQiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbIioiXSwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iLCJkZWZhdWx0LXJvbGVzLXNrb2l5Il19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSIsInNpZCI6IjBlNjZhMjUwLTYxN2UtNGIzOC04NDE5LTM4NWE2MWU5NGY3NCIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiSm9obiBEb2UiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJhZG1pbiIsImdpdmVuX25hbWUiOiJKb2huIiwiZmFtaWx5X25hbWUiOiJEb2UiLCJlbWFpbCI6ImFkbWluQGdtYWlsLmNvbSJ9.ds4xVtgCm1GpsCxipVTTpPdfN19LMVbJqsw-BklfVeB9OhtnijoJhU-cZkjU3-kR4C1fUHPUhLKlmnO1782SPAojnzGmg192f2GEWVJdWVxL5cxmJxu-PtT6G_HRIZ6QSA-eqPqmtrEyBFDMGNYvcehb6mZ-ZOls3KT_ZaOLBl8pBXLp_92O9bCRqqaa5dM68RFa8v7ypJAVuf8awuErPRY0MgOtJWNe6JttEquo5XGjmrUS2fRiZ2dLGXFfyWaY_ZOFevf-QX8ew8zEZOLOTUOj52K4zMOl4yaO7g0GM7mu08tR_VT-9SV1Y3b3HlH6wzPy-ycZlnPZDgNsT2LYhg"
    local client_id = "skoiy-client"
    local client_secret = "jlJBVW21q0wG1OrVrkj3Y5fsAeAIRDGz"

    local httpc = http:new()
    -- step 1: validate the token
    local res, err = httpc:request_uri(conf.introspection_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = "Bearer " .. access_token },
        body = "token=" .. token .. "&client_id=" .. client_id .. "&client_secret=" .. client_secret,
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

    return true -- all is well
  end

  function M.injectIDToken(idToken)
    local tokenStr = cjson.encode(idToken)
    ngx.req.set_header("X-ID-Token", ngx.encode_base64(tokenStr))
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