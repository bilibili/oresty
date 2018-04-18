--
-- User: tangjunxing
-- Date : 2017/08/31
--

local _M = {
    version = 190924
}

local cjson = require 'cjson.safe'

function _M.apply(route, method, params)
    local ctrl = package.loaded[(route or '')]
    if not ctrl then
        ngx.status = 404
        error('CTRL_NOT_FOUND')
    elseif not ctrl[method] then
        ngx.status = 404
        error('METHOD_NOT_FOUND')
    end
    local ret = ctrl[method](params)
    if type(ret) == 'table' then
        ngx.header.content_type = 'application/json'
        return cjson.encode(ret)
    elseif type(ret) == 'string' then
        ngx.header.content_type = 'text/plain'
        return ret
    else
        error('UNKNOWN_RET_CONTENT_TYPE')
    end
end

return _M
