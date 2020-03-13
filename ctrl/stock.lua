--
-- tjx@20200308
--

local client = require 'lib.client'
local cjson = require 'cjson.safe'
local serpent = require 'serpent'
local config = require 'config.config'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    local id = params.id or ''
    local key = 'e9a53708d6efa874db3134a3da7c4993'
    local url = 'http://web.juhe.cn:8080/finance/stock/'
    local ret

    if ngx.re.match(id, '^(sh|sz)[0-9]{6}$') then
        ret = client.get(url..'hs', {
            query = {
                key = key,
                gid = id,
            }
        })
    elseif ngx.re.match(id, '^[0-9]{5}$') then
        ret = client.get(url..'hk', {
            query = {
                key = key,
                num = id,
            }
        })
    elseif ngx.re.match(id, '^[a-z]{2,4}$') then
        ret = client.get(url..'usa', {
            query = {
                key = key,
                gid = id,
            }
        })
    else
        ngx.status = 404
        return '<pre>Usage:\ncurl pri.tjx.be?id=00700\ncurl pri.tjx.be?id=sh600436\ncurl pri.tjx.be?id=baba</pre>'
    end

    ngx.log(ngx.ERR, ret.body)
    local r = (cjson.decode(ret.body) or {}).result[1].data
    return r.lastestpri or r.nowPri

end

return _M
