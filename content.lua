--
-- tjx@20200308
--

local lup = require 'lib.lup'
local route = require 'lib.route'
local config = require 'config.config'

local r = route.new('/home/tjx/oresty/ctrl/', config.debug)

return function()

    local params = lup._REQUEST()

    local ctrl = params.r or lup.basename(ngx.var.document_uri)

    if lup.empty(ctrl) then
        ctrl = 'home'
    end

    local method = params.method or ngx.req.get_method():lower()

    r:dispatch(ctrl, method, params)

end
