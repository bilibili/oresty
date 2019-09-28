# Oresty

基于openresty的web框架
- 支持异步任务，异步IO
- 比go性能好，比PHP入门简单

## Benchmark

go
php
oresty

## Usage

    bash check-env.sh

    ln -s config_dev config

    install oresty /etc/init.d/oresty

    /etc/init.d/oresty start

    ps aux|grep oresty

    iresty/lua-resty-etcd: Nonblocking Lua etcd driver library for OpenResty
    https://github.com/iresty/lua-resty-etcd

## lib/tlcache.lua

- 缓存库，设计理念源于lua-resty-mlcache
- 区别在于可以再配置一层mongo或者redis实现多主机共享缓存
- 相对于mlcache的两层缓存（L1-upvalue，L2-shdict），tlcache是三级缓存
- TODO: 第三级缓存支持锁，避免多主机并发场景下的多次初始化

    --
    -- 现在site.conf 里面添加lua_shared_dict配置
    --
    lua_shared_dict tlcache 100m;

    local tlcache = require 'lib.tlcache'
    local cache1 = tlcache.new('cache1', 'tlcache', {
        ttl = 10,
        neg_ttl = 10,
        mongo_config = {}
        redis_config = {}
    })
    while 1 do
        cache1:get('key1', {ttl = 10, neg_ttl}, function()
            ngx.say(ngx.ERR, ngx.time())
        end)
        ngx.sleep(1)
    end

## lib/stat.lua

统计库，支持Prometheus格式输出

    --
    -- 启动stat进程，注意只需要在一个worker里面启动
    --
    init_worker_by_lua_bock {
        if ngx.worker.id() == 1 then
            local stat = require 'lib.stat'    
            stat.start()
        end
    }

    --
    -- 在content_by_lua或者log_by_lua等阶段使用，incr是唯一接口
    --
    local stat = require 'lib.stat'    
    local s = stat.new('label_name=label_value')
    s:incr('key_name', 123)

    --
    -- 输出Prometheus的方法
    --
    local metrics = stat.get_metrics()
    for _, m in pairs(metrics) do
        ngx.say(m.metric, m.labels or '', ' ', m.value)
    end

    --
    -- 本库会统计好count，delta，avg等数值输出，如下
    --
    key_name{label_name="label_value"} 123
    key_name_count{label_name="label_value"} 1
    key_name_delta{label_name="label_value"} 123
    key_name_avg{label_name="label_value"} 123
    

## lib/swoole.lua

    用lua实现swoole，task-workers和request-workers隔离

## lup.lua

    用lua实现PHP的function

## client.lua

http客户端封装库，依赖lua-resty-http
https://github.com/ledgetech/lua-resty-http
设计理念是建立和php-guzzle接口完全兼容的lua库
接口和PHP开源项目Guzzle完全一致
http://docs.guzzlephp.org/


    local client = require 'lib.client'
    local ret = client.get('http://baidu.com', {
        timeout = 1000                  -- timeout in ms
        retry = 3,                      -- 网络错误时候，重试次数
        retry_interval = 1              -- retry interval in second
        proxy = 'http://baidu.com',     -- 代理
        headers = {                     -- http-header 指定
            ['X-Auth'] = 'nihao'
        },
        query = {                       -- url的参数部分
            ni = 'hao'
        }
    })

    --
    -- send post request
    --
    local ret = client.post('http://baidu.com', {
        --
        -- body will be encoded with json
        -- content_type in header is 'application/json'
        --
        json = { 
            ni = 'hao'
        }
    })
    local ret = client.post('http://baidu.com', {
        --
        -- body will be encoded with json
        -- content_type in header is 'application/x-www-form-urlencoded'
        --
        form_params = {
            ni = 'hao'
        }
    })
    local ret = client.post('http://baidu.com', {
        body = 'BODY_CONTENT'
    })

    --
    -- send other request
    --
    client.delete(url)
    client.put(url)
    client.options(url)

    --
    -- deal with output
    --

## Changelog

### 20190928 
- 更新README，添加client,stat,tlcache的使用说明
- 添加tlcache

### 20190915 
- 升级OpenResty到1.15
- 升级route.lua
- 升级redis_client.lua
- 新增lua-resty-etcd
