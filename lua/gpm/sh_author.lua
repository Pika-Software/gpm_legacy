local GPM = GPM
GPM.Author = GPM.Author or {}

local function parseAuthor(str)
    local name = string.match(str, '^(.-)%s?[<%(]') or string.match(str, '.+')
    local email = string.match(str, '<(.-)>')
    local url = string.match(str, '%((.-)%)')

    return {
        name = name,
        email = email,
        url = url
    }
end

local mt = {}
mt.__index = mt

function mt:__eq(other)
    return istable(other) and
        self.name == other.name and
        self.email == other.email and
        self.url == other.url
end

function mt:__tostring()
	local buffer = { self.name }
	if self.email then buffer[#buffer+1] = ' <' .. self.email .. '>' end
	if self.url then buffer[#buffer+1] = ' (' .. self.url .. ')' end
	return table.concat(buffer)
end

function mt.new(v)
    assert(isstring(v) or istable(v), 'author must be a parsable string or table')

    if isstring(v) then
        v = parseAuthor(v)
    end

    assert(v.name, 'failed to parse author name')

    return setmetatable({
        name = v.name,
        email = v.email,
        url = v.url
    }, mt)
end

setmetatable(GPM.Author, { __call = function(_, ...) return mt.new(...) end })
