--
-- tjx@20200308
--

local lup = require 'lib.lup'
local route = require 'lib.route'

local rt = route.new()

return function()

    local params = lup._REQUEST()

    local ctrl = params.r or lup.basename(lup.trim(ngx.var.document_uri, '/'))

    if lup.empty(ctrl) then
        ctrl = 'home'
    end

    local method = params.method or ngx.req.get_method():lower()

    rt:dispatch(nil, ctrl, method, params)

end
