--
-- tjx@20190929
--

local _M = {
    version = 190924
}

local mysql = require 'resty.mysql'
local serpent = require 'serpent'
local lup = require 'lib.lup'

function _M.new(config)
    return setmetatable({conf = config}, {__index = _M})
end

function _M.query(self, sql)
    local conf = self.conf
    local db = mysql:new()
    db:set_timeout(5000)
    local retry = 2
    local res, err, errcode, sqlstate
    while retry > 0 do
        res, err, errcode, sqlstate = db:connect{
            host = conf.host,
            port = conf.port,
            database = conf.database,
            user = conf.user,
            password = conf.password,
            charset = 'utf8',
            max_packet_size = 1024 * 1024,
        }
        if res then
            res, err, errcode, sqlstate = db:query(sql)
            if res then
                db:set_keepalive(10000, 50)
                return res
            end
        end
        db:close()
        ngx.log(ngx.ERR, 'QUERY_ERR_'..serpent.line{
            retry = retry,
            res = res,
            err = err,
            errcode = errcode,
            sqlstate = sqlstate,
            sql = sql,
        })
        retry = retry - 1
        ngx.sleep(0.1)
    end
    error('MYSQL_ERROR_RETRIED')
end

return _M
