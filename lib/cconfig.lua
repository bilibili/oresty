local client = require 'lib.client'
local lup = require 'lib.lup'
local cjson = require 'cjson.safe'
local config = require 'config.config'

local _M = {}

local cconfig = {}
local mtime = 0

function _M.get(key)

    local url = config.cconfig_url

    if not url then
        return nil
    end

    local ret, r
    ngx.update_time()
    if ngx.time() > mtime + 10 then
        ret = lup.a(client.get, url, {timeout=100, retry=2})
        if ret then
            cconfig = cjson.decode(ret.body) or cconfig
            mtime = ngx.time()
        end
    end

    return (cconfig or {})[key]

end

return _M
