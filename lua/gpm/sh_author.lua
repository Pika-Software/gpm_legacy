local GPM = GPM
GPM.Author = GPM.Author or {}

local function parseAuthor(str)
    local name = string.match(str, '^(.-)%s?[<%(]') or string.match(str, '.+')
    local url = string.match(str, '<(.-)>')
    local email = string.match(str, '%((.-)%)')

    return {
        name = name,
        url = url,
        email = email
    }
end

local mt = {}
mt.__index = mt

function mt:__eq(other)
    return istable(other) and
        self.name == other.name and
        self.url == other.url and
        self.email == other.email
end

function mt:__tostring()
	local buffer = { self.name }
	if self.url then buffer[#buffer+1] = ' <' .. self.url .. '>' end
	if self.email then buffer[#buffer+1] = ' (' .. self.email .. ')' end
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
        url = v.url,
        email = v.email
    }, mt)
end

setmetatable(GPM.Author, { __call = function(_, ...) return mt.new(...) end })
