local GPM = GPM
GPM.Author = GPM.Author or {}

local function parseAuthor( str )
	local name = str:match( '^(.-)%s?[<%(]' ) or str:match( '.+' )
	local email = str:match( '<(.-)>' )
	local discord = str:gsub( '%s*([%g]+)%s*(#)%s*([%d]+)%s*', '%1%2%3' )
	local url = str:match( '%((.-)%)' )

	return {
		name = name,
		email = email,
		discord = discord,
		url = url
	}
end

local mt = {}
mt.__index = mt

do
	local table_concat = table.concat
	function mt:__tostring()
		local buffer = { self.name }
		if self.email then buffer[#buffer + 1] = ' <' .. self.email .. '>' end
		if self.discord then buffer[#buffer + 1] = ' (' .. self.discord .. ')' end
		if self.url then buffer[#buffer + 1] = ' (' .. self.url .. ')' end
		return table_concat( buffer )
	end
end

do
	local getmetatable = getmetatable
	function mt:__eq( other )
		return getmetatable( other ) == mt and
			self.name == other.name and
			self.email == other.email and
			self.discord == other.discord and
			self.url == other.url
	end
end

do

	local assert = assert
	local type = type

	function mt.new( v )
		assert( type( v ) == "string" or type( v ) == "table", 'author must be a parsable string or table' )

		if type( v ) == "string" then
			v = parseAuthor(v)
		end

		assert( v.name, 'failed to parse author name' )

		return setmetatable({
			name = v.name,
			email = v.email,
			discord = v.discord,
			url = v.url
		}, mt)
	end

end

setmetatable(GPM.Author, { __call = function(_, ...) return mt.new(...) end })