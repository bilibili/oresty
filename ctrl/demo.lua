local template = require 'resty.template'

local _M = {}

function _M.get(params)
    template.render('view.html', {
        message = 'Hello, World!' 
    })

    return params
end

return _M
