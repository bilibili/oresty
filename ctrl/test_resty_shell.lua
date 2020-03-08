--
-- tjx@20200308
--

local lup = require 'lib.lup'

local _M = {}

function _M.get(params)
    lup.exec158('sleep 1')
    return 'ss'..lup.filesize('/etc/issue')
end

function _M.get2(params)
    lup.exec('sleep 1')
    return 'ii'
end

return _M
