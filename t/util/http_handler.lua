local http = require('resty.http')
local json = require('cjson')

return function (node, conf)
    ngx.log(ngx.INFO, "http_handler node: ", json.encode(node), " conf: ", json.encode(conf))
    conf = conf or {}
    local httpc = http.new()
    local uri = "http://" .. node.host .. ":" .. node.port
    local res, err = httpc:request_uri(uri, {
        method = conf.method or "GET",
        path = conf.path or "/status",
    })
    if not res then
        ngx.log(ngx.ERR, "failed to request: ", err)
        return false
    end
    return true, res.status
end