local mod_name = (...):match ( "^(.*)%..-$" )

local misc = require ( mod_name .. ".misc" )
local attachpairs_start = misc.attachpairs_start

local setmetatable = setmetatable
local pcall = pcall

local colmt = require ( mod_name .. ".colmt" )
local gridfs = require ( mod_name .. ".gridfs" )

local dbmethods = { }
local dbmt = { __index = dbmethods }

function dbmethods:cmd(q)
    local collection = "$cmd"
    local col = self:get_col(collection)
    
    local c_id , r , t = col:query(q)

    if t.QueryFailure then
        return nil, "Query Failure"
    elseif not r[1] then
        return nil, "No results returned"
    elseif r[1].ok == 0 then -- Failure
        return nil , r[1].errmsg , r[1] , t
    else
        return r[1]
    end
end

function dbmethods:listcollections ( )
    local col = self:get_col("system.namespaces")
    return col:find( { } )
end

function dbmethods:dropDatabase ( )
    local r, err = self:cmd({ dropDatabase = true })
    if not r then
        return nil, err
    end
    return 1
end

local function pass_digest ( username , password )
    return ngx.md5(username .. ":mongo:" .. password)
end

--  XOR two byte strings together
local function xor_bytestr( a, b )
    local res = ""    
    for i=1,#a do
        res = res .. string.char(bit.bxor(string.byte(a,i,i), string.byte(b, i, i)))
    end
    return res
end

-- A simple implementation of PBKDF2_HMAC_SHA1
local function pbkdf2_hmac_sha1( pbkdf2_key, iterations, salt, len )
    local u1 = ngx.hmac_sha1(pbkdf2_key, salt .. string.char(0) .. string.char(0) .. string.char(0) .. string.char(1))
    local ui = u1
    for i=1,iterations-1 do
        u1 = ngx.hmac_sha1(pbkdf2_key, u1)
        ui = xor_bytestr(ui, u1)
    end
    if #ui < len then
        for i=1,len-(#ui) do
            ui = string.char(0) .. ui
        end
    end
    return ui
end

function dbmethods:add_user ( username , password )
    local digest = pass_digest ( username , password )
    return self:update ( "system.users" , { user = username } , { ["$set"] = { pwd = password } } , true )
end

function dbmethods:auth(username, password)
    local r, err = self:cmd({ getnonce = true })
    if not r then
        return nil, err
    end
 
    local digest = ngx.md5( r.nonce .. username .. pass_digest ( username , password ) )

    r, err = self:cmd(attachpairs_start({
            authenticate = true ;
            user = username ;
            nonce = r.nonce ;
            key = digest ;
         } , "authenticate" ) )
    if not r then
        return nil, err
    end
    return 1
end

function dbmethods:auth_scram_sha1(username, password)
    local user = string.gsub(string.gsub(username, '=', '=3D'), ',' , '=2C')
    local nonce = ngx.encode_base64(string.sub(tostring(math.random()), 3 , 14))
    local first_bare = "n="  .. user .. ",r="  .. nonce
    local sasl_start_payload = ngx.encode_base64("n,," .. first_bare)
    
    r, err = self:cmd(attachpairs_start({
            saslStart = 1 ;
            mechanism = "SCRAM-SHA-1" ;
            autoAuthorize = 1 ;
            payload =  sasl_start_payload ;
         } , "saslStart" ) )
    if not r then
        return nil, err
    end
    
    local conversationId = r['conversationId']
    local server_first = r['payload']
    local parsed_s = ngx.decode_base64(server_first)
    local parsed_t = {}
    for k, v in string.gmatch(parsed_s, "(%w+)=([^,]*)") do
        parsed_t[k] = v
    end
    local iterations = tonumber(parsed_t['i'])
    local salt = parsed_t['s']
    local rnonce = parsed_t['r']

    if not string.sub(rnonce, 1, 12) == nonce then
        return nil, 'Server returned an invalid nonce.'
    end
    local without_proof = "c=biws,r=" .. rnonce
    local pbkdf2_key = pass_digest ( username , password )
    local salted_pass = pbkdf2_hmac_sha1(pbkdf2_key, iterations, ngx.decode_base64(salt), 20)
    local client_key = ngx.hmac_sha1(salted_pass, "Client Key")
    local stored_key = ngx.sha1_bin(client_key)
    local auth_msg = first_bare .. ',' .. parsed_s .. ',' .. without_proof
    local client_sig = ngx.hmac_sha1(stored_key, auth_msg)
    local client_key_xor_sig = xor_bytestr(client_key, client_sig)
    local client_proof = "p=" .. ngx.encode_base64(client_key_xor_sig)
    local client_final = ngx.encode_base64(without_proof .. ',' .. client_proof)
    local server_key = ngx.hmac_sha1(salted_pass, "Server Key")
    local server_sig = ngx.encode_base64(ngx.hmac_sha1(server_key, auth_msg))
    
    r, err = self:cmd(attachpairs_start({
            saslContinue = 1 ;
            conversationId = conversationId ;
            payload =  client_final ;
         } , "saslContinue" ) )
    if not r then
        return nil, err
    end
    parsed_s = ngx.decode_base64(r['payload'])
    parsed_t = {}
    for k, v in string.gmatch(parsed_s, "(%w+)=([^,]*)") do
        parsed_t[k] = v
    end
    if parsed_t['v'] ~= server_sig then
        return nil, "Server returned an invalid signature."
    end
    
    if not r['done'] then
        r, err = self:cmd(attachpairs_start({
            saslContinue = 1 ;
            conversationId = conversationId ;
            payload =  ngx.encode_base64("") ;
         } , "saslContinue" ) )
        if not r then
            return nil, err
        end
        if not r['done'] then
            return nil, 'SASL conversation failed to complete.'
        end
        return 1
    end
    return 1
end

function dbmethods:get_col(collection)
    if not collection then
        return nil, "collection needed"
    end

    return setmetatable ( {
            conn = self.conn;
            db_obj = self;
            db = self.db ;
            col = collection;
        } , colmt )
end

function dbmethods:get_gridfs(fs)
    if not fs then
        return nil, "fs name needed"
    end

    return setmetatable({
            conn = self.conn;
            db_obj = self;
            db = self.db;
            file_col = self:get_col(fs..".files");
            chunk_col = self:get_col(fs..".chunks");
        } , gridfs)
end

return dbmt
