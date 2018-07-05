--
-- User: tangjunxing
-- Date : 2017/09/14
--
-- lua-users wiki: Multi Tasking
-- http://lua-users.org/wiki/MultiTasking
--

local cjson = require 'cjson.safe'
local _M = {}
local _instance = nil
_M.__index = _M

function _M.new()
    return setmetatable({
        shared = ngx.shared.swoole,
        worker_id = ngx.worker.id(),
        worker_pid = ngx.worker.pid(),
        setting = {},
        events = {},
    }, _M)
end

function _M.get_instance()
    if not _instance then
        _instance = _M.new()
    end
    return _instance
end

local function handler(premature, self)
    if premature then
        return
    end
    while not ngx.worker.exiting() do
        local waiting = self.shared:rpop('waiting')
        if waiting then
            local task = cjson.decode(waiting) or {}
            local task_data = task.data
            local task_callback = self.events.task
            local finish_callback = self.events.finish
            local worker_error_callback = self.events.worker_error
            self.shared:set('worker_'..self.worker_id, waiting, 600)
            
            local ok, ret = xpcall(task_callback, function(err)
                return {
                    err = err, 
                    traceback = debug.traceback()
                }
            end, self, task.id, self.worker_id, task_data)
            if not ok then
                ret = ret or {}
                ngx.log(ngx.ERR, cjson.encode{
                    err_type = 'SWOOLE_ERROR',
                    err = ret.err,
                    traceback = ret.traceback,
                })
            end

            self.shared:delete('worker_'..self.worker_id)
            if finish_callback then
                finish_callback(self, task.id, self.worker_id, ret)
            end
            -- self.err = ret.err
            -- if worker_error_callback then
            --     worker_error_callback(self, task.id, self.worker_id, ret.err)
            -- end
        else
            ngx.sleep(2)
        end
    end
end

function _M.start(self)
    if self.worker_id and tonumber(self.worker_id) < self.setting.task_worker_num then
        ngx.timer.at(0, handler, self)
        return true
    end
    return false
end

function _M.on(self, name, callback)
    if name == 'Task' then
        self.events.task = callback
    elseif name == 'Finish' then
        self.events.finish = callback
    elseif name == 'WorkerError' then
        self.events.worker_error = callback
    else
        error('UNKNOWN_EVENT_NAME_'..name)
    end
end

function _M.stats(self)
    -- request_count => 1000, Server收到的请求次数
    -- start_time 服务器启动的时间
    -- connection_num 当前连接的数量
    -- accept_count 接受了多少个连接
    -- close_count 关闭的连接数量
    -- task_queue_num => 10,
    -- task_queue_bytes => 65536,
    -- worker_request_count => 当前Worker进程收到的请求次数
    -- tasking_num 当前正在排队的任务数
    -- timer_pending_count = ngx.timer.pending_count(),
    -- timer_running_count = ngx.timer.running_count(),
    require "resty.core.shdict"
    return {
        shared_free = self.shared.free_space and self.shared:free_space(),
        shared_capacity = self.shared.capacity and self.shared:capacity(),
        task_worker_num = self.setting.task_worker_num,
        worker_count = ngx.worker.count(),
        worker_exiting = ngx.worker.exiting(),
        task_count = #self.shared:get_keys(),
        waiting = self.shared:llen('waiting'),
    }
end

function _M.get_last_error(self)
    return self.err
end

function _M.task(self, data)

    if self:stats().waiting + 1 > 40480 then
        error('TASK_WAITING_40480')
    end

    local task_id = ngx.crc32_long(ngx.now() + os.clock())
    local length, err = self.shared:lpush('waiting', cjson.encode({
        id = task_id,
        data = data
    }))

    if not length then
        error(err)
    end

    return task_id
end

function _M.set(self, setting)
    for k, v in pairs(setting) do
        self.setting[k] = v
    end
end

return _M
