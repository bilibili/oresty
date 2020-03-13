local config = require 'config.config'
local tlcache = require 'lib.tlcache'
local lup = require 'lib.lup'

local cache = tlcache.new('cache1', 'tlcache', {
    ttl = 10,
    neg_ttl = 10,
    mongo_config = config.mongo,
    -- redis_config = config.redis,
})

while true do
    local val = cache:get('key1', nil, function()
        return {
            time = ngx.now(),
            ni = 'i',
        }
    end)
    lup.var_dump(val)
    ngx.sleep(1)
end
