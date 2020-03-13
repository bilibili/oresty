--
-- User: tangjunxing
-- Date : 2017/08/31
--

local _M = {}

local cjson = require 'cjson.safe'
local config = require 'config.config'
local lup = require 'lib.lup'
local redis = require 'lib.redis_retry'
local stat = require 'lib.stat'

function _M.abs_path(level, key)
    -- /data/acache/L1/disk00/a/1a/b9187bc2ad1ff204b85924e9027d1a0a
    local disks = config.levels[level].disks
    local disk = disks[tonumber('0x'..key:sub(1,2)) % #disks + 1]
    return string.format('%s/%s/%s/%s',
    disk,
    key:sub(32,32),
    key:sub(30,31),
    key
    ), disk
end

local function du(dir)
    return tonumber(lup.explode(nil, lup.exec('du -sk '..dir))[1]) or 0
end

local cleaner_loop = function()
    for level, level_config in pairs(config.levels) do
        local slower_level = level_config.slower
        for _, disk in ipairs(level_config.disks) do
            if level_config.max_size < lup.disk_used_space(disk) then
                local ret = redis.zrange(level..'_last_access', 0, 200) or {}
                for _, key in ipairs(ret) do
                    lup.a(function()
                        local path = _M.abs_path(level, key)
                        if slower_level then
                            assert(redis.zadd(slower_level..'_last_access', ngx.now(), key))
                            local slower_path = _M.abs_path(slower_level, key)
                            stat.incr(level..'_'..slower_level, 1, 0)
                            if not lup.file_exists(slower_path) and not lup.copy(path, slower_path) then
                                if not lup.file_exists(path) then
                                    assert(ngx.shared.access_count:set(key, 0))
                                    assert(redis.zrem(level..'_last_access', key))
                                end
                                return
                            end
                        else
                            redis.del(key)
                            stat.incr(level..'_DEL', 1, 0)
                        end
                        assert(redis.zrem(level..'_last_access', key))
                        assert(os.remove(path), 'OS_REMOVE_FAIL')
                        assert(ngx.shared.access_count:set(key, 0), 'ACCESS_COUNT_FAIL_')
                    end)
                end
            end
        end
        ngx.sleep(1)
    end
end

local manager_loop = function()

    local val = ngx.shared.manager:rpop('_')
    if not val then
        print('MANAGER_IDLE')
        ngx.sleep(5)
        return
    end

    local path = cjson.decode(val).path
    local key = lup.basename(path)
    local level = lup.explode('/', path)[3]
    local level_config = config.levels[level]
    local faster_level = level_config.faster

    --
    -- 复制到快盘，如果失败，停止
    --
    assert(redis.zadd(faster_level..'_last_access', ngx.now(), key))

    stat.incr(level..'_'..faster_level, 1, 0)
    if not lup.copy(path, _M.abs_path(faster_level, key)) then
        if not lup.file_exists(path) then
            assert(ngx.shared.access_count:set(key, 0), 'ACCESS_COUNT_FAIL')
            assert(redis.zrem(level..'_last_access', key))
        end
        return
    end

    assert(ngx.shared.access_count:set(key, 0), 'ACCESS_COUNT_FAIL')

    ngx.sleep(0.05)

end

function _M.start_manager()
    ngx.timer.at(0, function()
        while not ngx.worker.exiting() do
            lup.a(manager_loop)
        end
    end)
end

function _M.start_cleaner()
    ngx.timer.at(0, function()
        while not ngx.worker.exiting() do
            cleaner_loop()
        end
    end)
end

return _M

