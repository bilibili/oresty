--
-- User: tangjunxing
-- Date : 2017/08/31
--
--

local _M = {
    version = 171227
}

--[[

# upsig.lua

## Usage:

### 优先级说明

- upsig优先级高于um_sign
- 既没有upsig也没有um_sign，直接403
- 有upsig，走upsig，应等效于服务器上没有um_sign
- 只有um_sign，走um_sign，应等效于服务器上没有upsig
- 以上的{等效}包括限速，超时，ip限制，以及其他两份签名有冲突的点

### 示例代码

    if params.upsig then
        local ok, ret = pcall(upsig.check, 
        config.upsig_secrets, 
        ngx.var.remote_addr, 
        ngx.shared.uips,
        set_limit_rate)
        if not ok then
            ngx.log(ngx.ERR, ret)
        end
        if not ret then
            -- upsig通过
            break
        end
        ngx.log(ngx.ERR, ret)
        ngx.header['X-Upos-Auth'] = hash(ret) # 错误文本取hash值
        -- 返回403
    elseif params.um_sign and um_sign.check(config.secret_keys) then
        -- um_sign通过
        break
    else
        ngx.exit(403)
    end

## Design

    相关参数说明:

    1 > deadline: url过期时间(unix时间戳，单位秒)，默认值为0
        若请求的时间点超过deadline，则403

    2 > rules: rules是针对某些header的检测规则，由3个表合并成为最终的rules
        preset_rules为预置规则，platform_rules为对应平台的检测规则，url参数中的rule则为每个url自己添加的规则。rules有一条不过则403。具体rules数据结构见下

    3 > platform: 不同的platform遵循的rules不相同，具体见下

    4 > uipk: 单url的访问ip个数限制，默认值见下
        对于range和start都没有，或range=0或start=0的请求，若访问ip个数超过限制，则返回403，并废掉当前url，后面请求均403

    5 > uipv: 单url的访问次数限制，默认值见下
        对于range和start都没有，或range=0或start=0的请求，若访问次数超过限制，则返回403，并废掉当前url，后面请求均403

    6 > drate: 限速参数，单位byte/s，默认值见下，可以设置为区间或者单个值，如drate=500000-1000000或drate=500000
        下载速度要被限制为区间中的随机一个值，如drate=5000-10000时，下载速度可能被限制为5500或9000等

    7 > e: 加密参数，是将前面所列的任意一个或多个参数使用json encode之后进行自定义base64加密生成的
    操作e参数时需要先使用自定义base64解密，再进行json decode，取出的参数列表和前面那些参数等价。若e中的参数和e外部同名，则e外部的参数优先级更高

    8 > upsig: upsig是使用secretkey对前面整个uri签名生成的32位字符串，upsig错误时返回403

    具体实现细则以下方代码实现效果为准，文档仅供参考

## Publish

    file=./lib/upsig.lua
    url=$(curl -s -XPUT 'http://brivnote.tjx.be' --data-binary @$file 2>/dev/null)
    echo curl -s ${url}\#本地址请求一次后失效 \> upsig_$(sed -En 's/.*version = ([0-9]+)/\1/p' $file).lua 

### shared_uips
- 自己实现的话需要实现类似如下接口的一个模块
- 须传入支持:get(key)和:set(key,val,expire)的模块实例
- 下面是一个redis实现的shared_uips使用时shared_uips.new('127.0.0.1', 6379)

    local _M = {}
    local redis = require 'resty.redis'
    _M.__index = _M
    function _M.new(host, port)
        local red = redis.new()
        red:set_timeout(30000)
        local self = setmetatable({
            red = red,
            host = host,
            port = port,
        }, _M)
        return self
    end
    function _M.get(self, key)
        local red = self.red
        local ok, err = red:connect(self.host, self.port)
        assert(ok, err)
        local val = red:get(key)
        red:set_keepalive(10000, 5000)
        return val
    end
    function _M.set(self, key, val, expire)
        local red = self.red
        local ok, err = red:connect(self.host, self.port)
        assert(ok, err)
        red:set(key, val)
        red:expire(expire)
        red:set_keepalive(10000, 5000)
    end
    return _M

]]

local cjson = require 'cjson.safe'

--
-- 等效于php的strtr
-- 详细文档见
-- PHP: strtr - Manual
-- http://php.net/manual/en/function.strtr.php
--
local function strtr(str, from, to)
    local ret = {string.byte(str, 1, string.len(str))}
    local f = {string.byte(from, 1, string.len(from))}
    local t = {string.byte(to, 1, string.len(to))}
    local d = {}
    local i = 1
    for i=1,#from do
        d[f[i]] = t[i]
    end
    for k, v in pairs(ret) do
        if d[v] then
            ret[k] = d[v]
        end
    end
    return string.char(unpack(ret))
end

--
-- 等效于php的explode
-- 详细文档见
-- PHP: explode - Manual
-- http://php.net/manual/en/function.explode.php
--
local function explode(sep, str)
    local cols = {}
    for m in (str or ''):gmatch('[^'..(sep or '%s').."]+") do
        cols[#cols + 1] = m
    end
    return cols
end

function _M.check(  -- check - upsig校验入口
    secrets, 
    uip,            -- (必须)终端用户的客户端ip，需要从自己的架构里面取得，不一定是remote_addr
    shared_uips,    -- (非必须)默认会使用ngx.shared.uips
    set_limit_rate, -- (非必须)默认会使用ngx.var.limit_rate，可以自己定义限速的模块
    preset_rules, 
    platform_rules
    )

    ngx.header['X-Upsig-Version'] = _M.version

    --
    -- upsig防篡改
    --                
    -- http://domain /path/to/file?start=11&a=b &upsig= 158caff1fdecb2256eab64be96f90c1a &start=22
    --               +-----------[1]----------+ +-[2]-+ +--------------[3]-------------+ +--[4]--+
    --
    -- 1. to_sign被签名部分
    -- 2. upsig识别字符串
    -- 3. upsig值
    -- 4. 播放器附加的额外参数，不当作可用参数解析，如上面的case，params.start应该解析为11而不是22
    --
    local to_sign, count = string.gsub(ngx.var.request_uri, '&upsig=.*$', '')
    if count ~= 1 or
        ngx.var.arg_upsig ~= ngx.md5(to_sign..secrets[1]) and 
        ngx.var.arg_upsig ~= ngx.md5(to_sign..secrets[2]) then
        return 'bad_upsig'
    end
    local params = ngx.decode_args(explode('?', to_sign)[2] or '') or {}

    --
    -- 解密e参数, 和params的键冲突时，e的优先级低
    -- b64 -> json -> encrypt_params
    --
    local b64 = strtr(
    params.e or '',
    'dGowRZJFN8-th7nAK6rWUIX9T2kqu5iQ4mEbe0xCLfODvlYSV1gzMBja3Hcys_pP', 
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    )
    local e = cjson.decode(ngx.decode_base64(b64))
    if type(e) == 'table' then
        for k, v in pairs(e) do
            params[k] = params[k] or v
        end
    end

    --
    -- 检查超时，deadline不存在等价于deadline=0，直接403
    --
    if (tonumber(params.deadline) or 0) < ngx.time() then
        return 'deadline'
    end

    --
    -- platform 黑名单 
    --
    if ({bilihelper=1,pdc=1,mobile=1})[params.platform or ''] then
        return 'platform'
    end

    --
    -- preset_rules，预置
    -- 以下两块规则分别用于实现referer白名单，ua黑名单
    --
    local preset_rules = preset_rules or {
        {
            {'nr', 'rf', [[^$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?bilibili\.tv(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?acgvideo\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?hdslb\.net(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?bilibili\.cn(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?mincdn\.org(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?mincdn\.net(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?baka\.im(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?drawyoo\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?bilibiligame\.net(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?bilibili\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?hdslb\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?biligame\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?biligame\.net(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?im9\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?bilibili\.co(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?acg\.tv(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?baidu\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?iqiyi\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?weibo\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?sogou\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?qq\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?douban\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?hao123\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?m\.sm\.cn(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?le\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?so\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?alipay\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?taobao\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?mi\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?jx3.xoyo\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?vgtime\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?blizzardtv\.cn(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?blizzard\.cn(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?100bt\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?gamersky\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?uuu9\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?saraba1st\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?b5csgo\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?vice\.cn(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/flymedia\.co\.jp.*$]],},
            {'nr', 'rf', [[^(http|https):\/\/jx3\.xoyo\.com.*$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?37man\.com(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/(.+\.)?mcbbs\.net(\/.*)?$]],},
            {'nr', 'rf', [[^(http|https):\/\/uiiiuiii\.com.*$]],},
        },
        {{'r', 'ua', '^$',}},
        {{'r', 'ua', 'Lavf.*',}},
        {{'r', 'ua', 'ijkplayer.*',}},
        {{'r', 'ua', 'Ysten.*',}},
        {{'r', 'ua', 'RealtekVOD.*',}},
        {{'r', 'ua', 'ttkan.*',}},
        {{'r', 'ua', 'Downloader.*',}},
        {{'r', 'ua', 'Python.*',}},
        {{'r', 'ua', 'VLC.*',}},
        {{'r', 'ua', 'libcurl.*',}},
        {{'r', 'ua', 'curl.*',}},
        {{'r', 'ua', 'RestSharp.*',}},
        {{'r', 'ua', 'NSPlayer.*',}},
    }

    if not platform_rules then
        platform_rules = {}
        --
        -- platform_rules
        --
        local platform = params.platform or ''
        --
        -- platform=pc且UA不包含PlayStation && referer == '' or nil, 403
        --
        if platform == 'pc' then
            platform_rules[#platform_rules + 1] = { { 'nf', 'ua', 'PlayStation', }, { 'r', 'rf', '^$', }, }
        end
        --
        -- 对于platform=pc 或者 platform=live 或者 platform=ﬂash 或者 platform=html5 以外 且带X-Requested-With 这个HTTP Header的做请求403 
        --
        if not ({flash=1, pc=1, live=1, html5=1})[platform] then
            platform_rules[#platform_rules + 1] = { { 'r', 'rw', '.+', }, }
        end
        --
        -- 对于platform=pc 或者 platform=live 或者 platform=ﬂash 或者 platform=html5 或者 platform为空 以外 且UA 中带Windows的请求 全部403
        --
        if not ({flash=1, pc=1, live=1, html5=1})[platform] and platform ~= '' then
            platform_rules[#platform_rules + 1] = { { 'f', 'ua', 'Windows', }, }
        end
        --
        -- 对于platform=pc 或者 platform=live 或者 platform=ﬂash 或者 platform=html5 或者platform为空 以外 且请求中带Referer的请求 全部403
        --
        if not ({flash=1, pc=1, live=1, html5=1})[platform] and platform ~= '' then
            platform_rules[#platform_rules + 1] = { { 'f', 'rf', '.+', }, }
        end
        --
        -- platform=android,android_tv 或 pc 且UA 包含 AppleCoreMedia, 403
        --
        if ({android=1, android_tv=1, pc=1})[platform] then 
            platform_rules[#platform_rules + 1] = { { 'f', 'ua', 'AppleCoreMedia', }, }
        end
        --
        -- platform != (android,androidG,androidtv,android_i,html5) 且 UA带有 stagefright或 Dalvik 或 Android字段, 403
        --
        if not ngx.re.match(platform, [[(android|html5)]], 'joi') then
            platform_rules[#platform_rules + 1] = { { 'r', 'ua', 'stagefright|dalvik|android', }, }
        end
    end

    local rules = {}
    --
    -- preset_rules, platform_rules, url_rules合并
    --
    for _, rule in ipairs(preset_rules or {}) do
        rules[#rules + 1] = rule
    end
    for _, rule in ipairs(platform_rules or {}) do
        rules[#rules + 1] = rule
    end
    for _, rule in ipairs(params.rules or {}) do
        rules[#rules + 1] = rule
    end

    --
    -- rules引擎，规则引擎
    --
    for _, rule in ipairs(rules) do
        local match_count = 0
        for _, ru in ipairs(rule) do
            local func = ({
                ne = function(s, p) return s ~= p end,
                r  = function(s, p) return ngx.re.match(s, p, 'joi') end,
                nr = function(s, p) return not ngx.re.match(s, p, 'joi') end,
                f  = function(s, p) return s:find(p) end,
                nf = function(s, p) return not s:find(p) end
            })[ru[1]]
            local subject = ({
                ua  = params.ua or ngx.var.http_user_agent,
                rw  = ngx.var.http_x_requested_with,
                rf  = params.rf or ngx.var.http_referer,
                uip = uip,
                h   = ngx.var.host,
            })[ru[2]] or ''
            local pattern = ru[3] or ''
            if func(subject, pattern) then
                match_count = match_count + 1
            else
                break
            end
        end
        if match_count == #rule then
            return cjson.encode(rule)
        end
    end

    --
    -- 对且只对
    -- (range和start都没有)
    -- 或
    -- range=0
    -- 或
    -- start=0
    -- 的请求，单url限制uipk个ip，每个ip限制uipv次播放
    --
    local http_range = ngx.var.http_range
    local start = ngx.var.arg_start
    shared_uips = shared_uips or ngx.shared.uips
    if (not http_range and not start) or 
        (http_range and string.find(http_range, 'bytes=0')) or
        start == '0' then
        local uipk = params.uipk or 5
        local uipv = params.uipv or 5
        local urlhash = ngx.crc32_long(ngx.var.request_uri)
        local uips = cjson.decode(shared_uips:get(urlhash)) or {}
        uips[uip] = (uips[uip] or 0) + 1
        local uip_count = 0
        for _, _ in pairs(uips) do
            uip_count = uip_count + 1
        end
        if uip_count > tonumber(uipk) then
            return 'uipk'
        end
        if uips[uip] > tonumber(uipv) then
            return 'uipv'
        end
        shared_uips:set(urlhash, cjson.encode(uips), 7200)
    end

    --
    -- drate限制，单位byte/s，支持drate=500000,drate=500000-10000000
    --
    local lower, upper = unpack(explode('-', params.drate or ''))
    lower = lower or 500000
    math.randomseed(os.clock())
    set_limit_rate = set_limit_rate or function(rate)
        ngx.var.limit_rate = rate
    end
    set_limit_rate(math.random(lower, upper or lower))

    return nil
end

return _M
