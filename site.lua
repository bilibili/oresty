--
-- tjx@20200308
--

local lup = require 'lib.lup'
local route = require 'lib.route'
local rt = route.new()

local _M = {}

function _M.init()
    local process = require 'ngx.process'

    local ok, err = process.enable_privileged_agent()
    if not ok then
        ngx.log(ngx.ERR, 'enables privileged agent failed error:', err)
    end

    ngx.log(ngx.INFO, 'process type: ', process.type())

end

function _M.init_worker()
    local process = require 'ngx.process'
    --
    -- privileged agent
    --
    if process.type() == 'privileged agent' then
        ngx.log(ngx.ERR, 'This is the privileged agent with root privilege.')
    end

end

function _M.content()

    local params = lup._REQUEST()

    local ctrl = params.r or lup.basename(lup.trim(ngx.var.document_uri, '/'))

    if lup.empty(ctrl) then
        ctrl = 'home'
    end

    local method = params.method or ngx.req.get_method():lower()

    rt:dispatch(nil, ctrl, method, params)

end

return _M
