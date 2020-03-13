--
-- User: tangjunxing
-- Date : 2017/08/31
--

local _M = {
    version = 190924
}

--[[
params = {
    cors = {
        {
            origins = {
                'http://*.baidu.co',
                'https://*.baidu.co',
                'http://*.baidu.com',
                'https://*.baidu.com',
            },
            methods = {
                'DELETE', 
                'PUT',
            },
            headers = {
                'Content-Type', 
                'X-Upos-Auth',
                'Range',
            },
            expose_headers = {
            },
            max_age_seconds = 1800,
        }
    }
}
]]

function _M.apply(params)

    local origin = ngx.var.http_origin
    if origin and params.cors then
        for _, cors in pairs(params.cors) do
            if not cors.origins then
                break
            end
            for _, allowed_origin in pairs(cors.origins) do
                if origin:match(allowed_origin:gsub("%.", "%%."):gsub("%*", "%.%*")) then
                    ngx.header["Access-Control-Allow-Origin"] = origin
                    if ngx.var.request_method == "OPTIONS" then
                        if cors.methods then
                            ngx.header["Access-Control-Allow-Methods"] = table.concat(cors.methods, ", ")
                        end
                        if cors.headers then
                            ngx.header["Access-Control-Allow-Headers"] = table.concat(cors.headers, ", ")
                        end
                        if cors.expose_headers then
                            ngx.header["Access-Control-Expose-Headers"] = table.concat(cors.expose_headers, ", ")
                        end
                        ngx.header["Access-Control-Allow-Credentials"] = "true"
                    else
                        ngx.header["Access-Control-Allow-Credentials"] = "true"
                        break
                    end
                    return
                end
            end
        end
    end

end

return _M
