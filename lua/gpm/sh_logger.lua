local GPM = GPM
GPM.Logger = GPM.Logger or {}

local colorSupport = MENU_DLL or not game.IsDedicated()

local colors = {
	gray = colorSupport and Color(128,128,128) or Color(192,192,192),
	white = Color(220, 220, 220),
	red = Color(255, 0, 0),
	yellow = Color(255, 255, 0),
	blue = Color(0, 0, 255),
	green = Color(0, 255, 0),
	server = colorSupport and Color(156, 241, 255, 200) or Color(0, 0, 255),
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

local function formatter(info)
	local time = formatTime(info.timestamp)
	local level = string.upper(info.level)
	local id = ('[%s]:'):format(info.id)
	local message = string.gsub(info.message, '{(%d+)}', function(i)
		i = tonumber(i)
		return (i and info.args[i] ~= nil) and tostring(info.args[i]) or ('{'..i..'}')
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

function mt:log(level, message, ...)
	local info = {
		id = self.id and tostring(self.id) or 'unknown',
		timestamp = os.time(),
		level = level and tostring(level) or 'info',
		message = tostring(message),
		args = {...}
	}

	local msg
	if isfunction(self.formatter) then
		msg = self.formatter(info)
	end

	if istable(msg) then
		MsgC(unpack(msg))
	elseif msg ~= nil and msg ~= false then
		print(msg)
	elseif msg == false then
		return
	else
		PrintTable(info)
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
	self:log('debug', message, ...)
end

function mt.new(id)
	assert(id == nil or isstring(id), 'id must be a string')

    return setmetatable({
		id = id,
		formatter = formatter,
    }, mt)
end

setmetatable(GPM.Logger, { __call = function(_, ...) return mt.new(...) end })
