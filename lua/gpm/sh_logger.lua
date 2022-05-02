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

local function formatTime()
	return os.date('%H:%M:%S')
end

local function formatter( info )
	local time = formatTime( info.timestamp )
	local level = info.level:upper()
	local id = ('[%s]:'):format( info.id )
	local message = info.message:gsub('{(%d+)}', function(i)
		i = tonumber( i )
		return (i and info.args[i] ~= nil) and tostring( info.args[i] ) or ('{' .. i .. '}')
	end)

	return {
		-- timestamp
		colors.gray,
		time, ' ',

		-- level
		levelColors[info.level] or levelColors['info'],
		level, ' ',

		-- id
		(SERVER and colors.server) or (CLIENT and colors.client) or colors.menu,
		id, ' ',

		-- message
		colors.white,
		message, '\n',
	}
end

local mt = {}
mt.__index = mt

do

	local type = type

	do

		local assert = assert

		function mt.new(id)
			assert( (id == nil) or type( id ) == "string", 'id must be a string' )

			return setmetatable({
				id = id,
				formatter = formatter,
			}, mt)
		end

	end

	do

		local PrintTable = PrintTable
		local tostring = tostring
		local os_time = os.time
		local unpack = unpack
		local print = print
		local MsgC = MsgC

		function mt:log( level, message, ... )
			local info = {
				id = self.id and tostring( self.id ) or 'unknown',
				timestamp = os_time(),
				level = level and tostring( level ) or 'info',
				message = tostring( message ),
				args = {...}
			}

			local msg
			if type( self.formatter ) == "function" then
				msg = self.formatter(info)
			end

			if type( msg ) == "table" then
				MsgC( unpack( msg ) )
			elseif (msg ~= nil) and (msg ~= false) then
				print( msg )
			elseif (msg == false) then
				return
			else
				PrintTable( info )
			end
		end

	end

end

function mt:fatal(message, ...)
	self:log('fatal', message, ...)
end

function mt:error(message, ...)
	self:log('error', message, ...)
end

function mt:warn(message, ...)
	self:log('warn', message, ...)
end

function mt:info(message, ...)
	self:log('info', message, ...)
end

function mt:debug(message, ...)
	--self:log('debug', message, ...)
end

setmetatable(Logger, { __call = function(_, ...) return mt.new(...) end })
