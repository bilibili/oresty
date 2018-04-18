--
-- User: tangjunxing
-- Date : 2017/12/20
--

local lfs = require 'lfs'
local serpent = require 'serpent'
local cjson = require 'cjson.safe'

local _M = {
    PATHINFO_DIRNAME = 1,
    PATHINFO_BASENAME = 2,
    PATHINFO_EXTENSION = 3,
    PATHINFO_FILENAME = 4,
    PHP_URL_SCHEME = 0,
    PHP_URL_HOST = 1,
    PHP_URL_PORT = 2,
    PHP_URL_USER = 3,
    PHP_URL_PASS = 4,
    PHP_URL_PATH = 5,
    PHP_URL_QUERY = 6,
    PHP_URL_FRAGMENT = 7,
}

function _M.var_dump(expression)
    print(serpent.block(expression))
end

function _M.scandir()
end

--
-- PHP: 错误控制运算符 - Manual
-- http://php.net/manual/zh/language.operators.errorcontrol.php
--
function _M.a(f, ...)
    local status, ret = pcall(f, ...)
    if status then
        return ret
    end
    ngx.log(ngx.ERR, ret)
    return nil
end

function _M._REQUEST()
    local params = {}
    local uri_args = ngx.req.get_uri_args()
    if type(uri_args) == 'table' then
        for k, v in pairs(uri_args) do
            params[k] = v
        end
    end
    local body_args = {}
    local http_content_type = ngx.var.http_content_type or ''
    if ngx.re.match(http_content_type, '^application/json\\b', 'jo') then
        ngx.req.read_body()
        body_args = cjson.decode(ngx.req.get_body_data())
    elseif http_content_type == 'application/x-www-form-urlencoded' then
        ngx.req.read_body()
        body_args = ngx.req.get_post_args()
    end
    if type(body_args) == 'table' then
        for k, v in pairs(body_args) do
            params[k] = v
        end
    end
    return params
end

function _M.hex2bin(data)
    return ((data or ''):gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function _M.json_encode(obj)
    return cjson.encode(obj)
end

function _M.json_decode(str)
    return cjson.decode(str)
end

function _M.exec(cmd)
    local tmpout = os.tmpname()
    local tmperr = os.tmpname()
    local ret = os.execute('('..cmd..') >'..tmpout..' 2>'..tmperr)
    local stdout = _M.file_get_contents(tmpout)
    os.remove(tmpout)
    local stderr = _M.file_get_contents(tmperr)
    os.remove(tmperr)
    ngx.log(ngx.INFO,
        ' cmd: ', cmd,
        ' ret: ', ret,
        ' stderr: ', stderr,
        ' stdout: ', stdout
    )
    if ret then
        return stdout
    end
    return nil, cjson.encode{
        ret = ret,
        stdout = stdout,
        stderr = stderr
    }
end

function _M.unlink(path)
    --return os.remove(path)
    return _M.exec('rm -f '..path)
end

function _M.rename(src, dst)
    -- return os.rename(src, dst)
    return _M.exec('mv '..src..' '..dst)
end

function _M.file_get_contents(file)
    local f, err = io.open(file, 'r')
    if not f then
        return nil, err
    end
    local content = f:read('*a')
    f:close()
    return content
end

function _M.file_put_contents(file, content)
    local f, err = io.open(file, 'w')
    if not f then
        return nil, err
    end
    f:write(content)
    f:close()
end

function _M.copy(src, dest)
    local dest_tmp = dest..os.clock()
    local f, err = io.open(src, 'rb')
    if not f then
        return nil, err
    end
    local content = f:read('*a')
    f:close()
    local f, err = io.open(dest_tmp, 'w')
    if not f then
        return nil, err
    end
    f:write(content)
    f:close()
    return os.rename(dest_tmp, dest)
    -- return _M.exec('cp '..src..' '..dst)
end

--
-- http://php.net/manual/en/function.parse-url.php
--
function _M.parse_url(url, component)
    component = component or -1
    return {
        host = string.gsub(url, "^.*://(%w+)(/.+)$", "%1"), 
        path = string.gsub(url, "^.*://(%w+)(/.+)$", "%2")
    }
end

function _M.is_executable(path)
    local attr = lfs.attributes(path)
    if attr then
        if string.sub(attr.permissions, 3, 3) == 'x' then
            return true
        end
    end
    return false
end

function _M.uniqid()
    return ngx.md5(ngx.time() + os.clock() + ngx.worker.pid())
end

function _M.file_exists(path)
    local f = io.open(path, "r")
    if not f then
        return false
    end
    io.close(f)
    return true
end

function _M.filesize(path)
    return (lfs.attributes(path) or {}).size
end

function _M.basename(str)
    return string.gsub(str, "(.*/)(.*)", "%2")
end

function _M.pathinfo(path, options)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end
    local dirname = string.sub(path, 1, pos)
    local basename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local filename = string.sub(basename, 1, extpos - 1)
    local extension = string.sub(basename, extpos + 1)
    local ret = {
        [_M.PATHINFO_DIRNAME] = dirname,
        [_M.PATHINFO_BASENAME] = basename,
        [_M.PATHINFO_FILENAME] = filename,
        [_M.PATHINFO_EXTENSION] = extension
    }
    if options then
        return ret[options]
    end
    return {
        dirname = ret[_M.PATHINFO_DIRNAME],
        basename = ret[_M.PATHINFO_BASENAME],
        filename = ret[_M.PATHINFO_FILENAME],
        extension = ret[_M.PATHINFO_EXTENSION],
    }
end

-- function _M.pathinfo(path, options)
--     if options == _M.PATHINFO_EXTENSION then
--         return string.gsub(path, "^(.*)%.(.*)$", "%2")
--     elseif options == _M.PATHINFO_FILENAME then
--         return string.gsub(path, "^(.*)%.(.*)$", "%1")
--     end
-- end

function _M.dirname(path)
    local dirname, count = path:gsub("[^/]+/*$", "")
    if dirname == "" then
        return path
    end
    return dirname
end

function _M.mkdir(path, mode, recursive)
    if lfs.attributes(path) then
        return true
    end
    local parent = _M.dirname(path)
    if not lfs.attributes(parent) then
        if not recursive then
            return nil, 'mkdir(): No such file or directory'
        end
        local ret, err = _M.mkdir(parent, mode, recursive)
        if not ret then
            return err
        end
    end
    local ret, err = lfs.mkdir(path)
    if not ret then
        return nil, err
    end
    if mode then
        local ret, err = os.execute("chmod "..mode.." "..path)
        if not ret then
            return nil, err
        end
    end
    return true
end

function _M.get_files(path, prepend_path_to_filenames)
    if path:sub(-1) ~= '/' then
        path = path..'/'
    end
    local pipe = io.popen('ls '..path..' 2> /dev/null')
    local output = pipe:read'*a'
    pipe:close()
    -- If your file names contain national characters
    -- output = convert_OEM_to_ANSI(output)
    local files = {}
    for filename in output:gmatch('[^\n]+') do
        if prepend_path_to_filenames then
            filename = path..filename
        end
        table.insert(files, filename)
    end
    return files
end

function _M.rand()
    math.randomseed((os.time()%100000000)*1000000+os.clock()*1000000)
    return math.random()*100000000000000
end

-- char arg[128] = "";
-- char ret[128] = "";
-- strcpy(arg, luaL_checkstring(L, 1));
-- statfs(arg, &st);
-- long long size = (st.f_blocks * st.f_bsize) / 1024;
-- long long used = ((st.f_blocks - st.f_bfree) * st.f_bsize) / 1024;
-- long long avail = (st.f_bavail * st.f_bsize) / 1024;
-- long long percent = (used) / (float)(used + avail) * 100;
-- sprintf(ret, "%-20s %ld %ld %ld %ld", arg, size, used, avail, percent);
-- lua_pushstring(L, ret);


function _M.disk_free_space(path)
    return tonumber(_M.explode('\n', _M.exec('df --output=avail '..path))[2])
end

function _M.disk_used_space(path)
    return tonumber(_M.explode('\n', _M.exec('df --output=used '..path))[2])
end

function _M.disk_total_space(path)
    return tonumber(_M.explode('\n', _M.exec('df --output=size '..path))[2])
end

function _M.strtr(str, from, to)
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

function _M.explode(sep, str)
    local cols = {}
    for m in (str or ''):gmatch('[^'..(sep or '%s').."]+") do
        cols[#cols + 1] = m
    end
    return cols
end

function _M.md5_file(path)
    local out, err = io.popen('md5sum '..path..'|awk \'{print $1}\'')
    if not out then
        return err
    end
    local ret = out:read(32)
    io.close()
    return ret
end

return _M
