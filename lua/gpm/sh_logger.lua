module( "GPM", package.seeall )

Logger = Logger or {}

-- For colorable server console check Billy's Github
-- https://github.com/WilliamVenner/gmsv_concolormsg

if not (MENU_DLL or not game.IsDedicated() or file.Exists( "lua/bin/gmsv_concolormsg_win64.dll", "GAME" )) and system.IsWindows() then
	print( "You can add some color to your gray console, just install: https://github.com/WilliamVenner/gmsv_concolormsg" )
end

local colors = {
	gray = Color(128,128,128),
	white = Color(220, 220, 220),
	red = Color(255, 0, 0),
	yellow = Color(255, 255, 0),
	blue = Color(0, 130, 255),
	green = Color(0, 255, 0),
	server = Color(156, 241, 255, 200),
	client = Color(255, 241, 122, 200),
	menu = Color(100, 220, 100, 200),
}

local levelColors = {
	fatal = colors.red,
	error = colors.red,
	warn = colors.yellow,
	info = colors.blue,
	debug = colors.green,
}

local mt = {}
mt.__index = mt

do

	local type = type

	do

		local assert = assert

		function mt.new(id)
			assert( (id == nil) or type( id ) == "string", 'id must be a string' )

			return setmetatable({["id"] = id}, mt)
		end

	end

	do
		local template = '%H:%M:%S'
		local os_date = os.date
		function mt:getTime()
			return os_date( template )
		end
	end

	do

		local SERVER = SERVER
		local CLIENT = CLIENT
		local tonumber = tonumber
		local tostring = tostring
		local id_template = "[%s]:"

		function mt:build( title, level, message, ... )
			local args = {...}
			return
			-- Timestamp
			colors.gray, self:getTime(), ' ',

			-- Log Level
			levelColors[ level ] or levelColors.info, level:upper(), ' ',

			-- Title
			(SERVER and colors.server) or (CLIENT and colors.client) or colors.menu, id_template:format( title ), ' ',

			-- Message
			colors.white, message:gsub('{(%d+)}', function( i )
				i = tonumber( i )
				return (i and args[i] ~= nil) and tostring( args[i] ) or ('{' .. i .. '}')
			end), '\n'
		end

	end

	do

		local MsgC = MsgC
		local tostring = tostring

		function mt:log( level, message, ... )
			MsgC( self:build( self.id and tostring( self.id ) or 'unknown', level and tostring( level ) or 'info', tostring( message ), ... ) )
		end

	end

end

function mt:fatal( message, ... )
	self:log( 'fatal', message, ... )
end

function mt:error( message, ... )
	self:log( 'error', message, ... )
end

function mt:warn( message, ... )
	self:log( 'warn', message, ... )
end

function mt:info( message, ... )
	self:log( 'info', message, ... )
end

do

	local developer = cvars.Number( "developer", 0 ) ~= 0
	cvars.AddChangeCallback("developer", function( name, old, new )
		developer = new ~= "0"
	end)

	function mt:debug( message, ... )
		if (developer) then
			self:log( 'debug', message, ... )
		end
	end

end

setmetatable( Logger, { __call = function(_, ...) return mt.new(...) end } )
