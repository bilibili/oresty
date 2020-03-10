<!-- vim-markdown-toc GFM -->

* [Oresty](#oresty)
    * [Benchmark - 基准测试](#benchmark---基准测试)
    * [Quick Start - 快速开始](#quick-start---快速开始)
    * [OpenResty目录结构](#openresty目录结构)
    * [Sentry - raven.lua](#sentry---ravenlua)
    * [lib/route.lua](#libroutelua)
    * [resty命令行](#resty命令行)
    * [lib/tlcache.lua Oresty独有的库，基于mlcache和lrucache](#libtlcachelua-oresty独有的库基于mlcache和lrucache)
    * [lib/stat.lua](#libstatlua)
    * [lib/swoole.lua](#libswoolelua)
    * [错误栈](#错误栈)
    * [lib/cors.lua](#libcorslua)
    * [lib/redis_clinet.lua](#libredis_clinetlua)
    * [lib/mongo_client.lua](#libmongo_clientlua)
    * [lib/mysql_clinet.lua](#libmysql_clinetlua)
    * [使用prometheus](#使用prometheus)
    * [lup.lua](#luplua)
    * [client.lua](#clientlua)
    * [竞品Alternatives](#竞品alternatives)
    * [引用Reference](#引用reference)
    * [Changelog](#changelog)
        * [20200310](#20200310)
        * [20200308](#20200308)
        * [20190929](#20190929)
        * [20190928](#20190928)
        * [20190915](#20190915)

<!-- vim-markdown-toc -->

# Oresty

基于OpenResty的web应用框架，旨在推广OpenResty在web应用领域的应用
- 支持异步任务，异步IO
- 比Go性能好，比PHP入门简单

## Benchmark - 基准测试

- Go
- PHP
- Oresty

## Quick Start - 快速开始

    #
    # 安装deb包，初始化应用环境
    #
    dpkg -i install.deb
    bash check-env.sh

    #
    # 启动程序，检测进程状况
    #
    /etc/init.d/oresty start
    ps aux|grep oresty

    #
    # 浏览器打开
    #
    http://127.0.0.1:2223

## OpenResty目录结构

    ./oresty/bin
    ./oresty/lualib
    ./oresty/luajit
    ./oresty/nginx
    ./oresty/site
    ./oresty/pod
    ./oresty/

## Sentry - raven.lua

## lib/route.lua

## resty命令行
    便捷的执行带参数的resty命令的技巧

    #!/usr/local/bin/env -S /usr/local/oresty/bin/resty --shdict 'prometheus_metrics 2M' -I ./lualib/

## lib/tlcache.lua Oresty独有的库，基于mlcache和lrucache

- lib/lrucache.lua OpenResty内置
    通过upvalue实现缓存

- lib/mlcache.lua 优质的第三方库
- 缓存库，设计理念源于lua-resty-mlcache
- 区别在于可以再配置一层mongo或者redis实现多主机共享缓存
- 相对于mlcache的两层缓存（L1-upvalue，L2-shdict），tlcache是三级缓存
- TODO: 第三级缓存支持锁，避免多主机并发场景下的多次初始化

```
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
```

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

## 错误栈

## lib/cors.lua

## lib/redis_clinet.lua

    local redis_client = require 'lib.redis_client'
    local red = redis_client.new()
    local ret = red:set()
    local red:get()

## lib/mongo_client.lua

    local mongo_client = require 'lib.mongo_client'
    local mdb = mongo_client.new()
    mdb:get()
    mdb:set()

## lib/mysql_clinet.lua

    local mongo_client = require 'lib.mongo_client'
    local mdb = mongo_client.new()
    mdb:get()
    mdb:set()

## 使用prometheus
knyar/nginx-lua-prometheus: Prometheus metric library for Nginx written in Lua
https://github.com/knyar/nginx-lua-prometheus

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

## 竞品Alternatives

- sumory/lor: a fast, minimalist web framework for lua based on OpenResty
https://github.com/sumory/lor

- leafo/lapis: A web framework for Lua and OpenResty written in MoonScript
https://github.com/leafo/lapis


## 引用Reference
- 序 · OpenResty最佳实践
https://moonbingbing.gitbooks.io/openresty-best-practices/

- bungle/awesome-resty: A List of Quality OpenResty Libraries, and Resources.
https://github.com/bungle/awesome-resty

- apache/incubator-apisix: Cloud-Native Microservices API Gateway
https://github.com/apache/incubator-apisix

## Changelog

### 20200310
- 添加prom.lua, zset.lua
- 添加toc目录

### 20200308
- 优化文档
- 添加prometheus.lua
- 添加sentry.lua
- 增加OpenResty1.17rc版本
- 增加支持lua-resty-shell非阻塞执行本地命令

### 20190929
- 更新安装方式，安装文档
- 添加select2.js
- 添加lib/mysql_client

### 20190928 
- 更新README，添加client,stat,tlcache的使用说明
- 添加tlcache

### 20190915 
- 升级OpenResty到1.15
- 升级route.lua
- 升级redis_client.lua
- 新增lua-resty-etcd
