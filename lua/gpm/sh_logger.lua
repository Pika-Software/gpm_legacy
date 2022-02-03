local GPM = GPM
GPM.Logger = GPM.Logger or {}

local mt = {}
mt.__index = mt

function mt:log(level, message, ...)
	-- TODO: make formatting
end

function mt.new(id)
	assert(id == nil or isstring(id), 'id must be a string')

    return setmetatable({
		id = id
    }, mt)
end

setmetatable(GPM.Logger, { __call = function(_, ...) return mt.new(...) end })
