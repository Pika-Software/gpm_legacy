-- For colorable server console check Billy's Github
-- https://github.com/WilliamVenner/gmsv_concolormsg

if not (MENU_DLL or not game.IsDedicated() or file.Exists( "lua/bin/gmsv_concolormsg_win64.dll", "GAME" )) and system.IsWindows() then
	print( "You can add some colors to your gray console, just install: https://github.com/WilliamVenner/gmsv_concolormsg" )
end

module( "GPM", package.seeall )

local logger = CreateClass("Logger")
logger.__index = logger

function logger:__index(key)
	if logger[key] ~= nil then
		return logger[key]
	end

	for _, t in ipairs(self.levels) do
		if t[1] == key then
			self[key] = function(self, ...)
				return self:log(key, ...)
			end

			return self[key]
		end
	end
end

-- Colors
-- @todo need more colors
logger.colors = {
	["white"] = Color( 225, 225, 225 ),
	["gray"] = Color( 128, 128, 128 ),
	["black"] = Color(0, 0, 0),
	["red"] = Color( 255, 85, 85 ),
	["green"] = Color( 85, 255, 85 ),
	["cyan"] = Color( 85, 255, 255 ),
	["blue"] = Color( 85, 85, 255 ),
	["purple"] = Color( 125, 85, 255 ),
	["yellow"] = Color( 255, 255, 85 ),
	["pink"] = Color( 255, 85, 255 ),
	["server"] = Color(156, 241, 255, 200),
	["client"] = Color(255, 241, 122, 200),
	["menu"] = Color(100, 220, 100, 200),
	["gmod"] = Color( 17,148,240 )
}

logger.colors["garry's mod"] = logger.colors["gmod"] -- gmod color ?? :)

-- Levels
logger.levels = {
	-- { "id", "displayName", "color" or Color(...) }
	{ "error", "Error", "red" },
	{ "warn", "Warn", "yellow" },
	{ "info", "Info", "cyan" },
	{ "debug", "Debug", "purple" }
}

function logger:getColor( clr )
	if isstring(clr) then
		if self.colors[clr] then return self.colors[clr] end

		return clr:ToColor()
	end

	if IsColor(clr) then return clr end
end

function logger:getLevel( level )
	if not level then return end

	-- Number level
	if isnumber( level ) then
		return self.levels[ level ]
	end

	-- String level
	if isstring( level ) then
		local lower_level = level:lower()
		for num, level_data in ipairs( self.levels ) do
			if (lower_level == level_data[1]:lower()) then
				return level_data
			end
		end

		return { level, self.colors.blue }
	end

	-- Custom or nil level
	return level
end

--- Format
-- @tparam { parsedLevel, level, args, time }
--
-- @return a table of MsgC args
function logger:format( data )
	local args = {}

	-- Timestamp
	do
		local timestamp = os.date("%H:%M:%S")
		table.insert( args, self.colors.gray )
		table.insert( args, timestamp )
	end

	//table.insert( args, Color(255, 255, 255) )

	-- Level
	do
		local level = data.parsedLevel
		if (level) then
			table.insert( args, " | " )

			if istable(level) then
				table.insert( args, self.colors[ level[3] ] )
				table.insert( args, level[2] )
			else
				table.insert( args, self.colors.white )
				table.insert( args, level )
			end
		end
	end

	table.insert( args, " " )

	-- Name
	do
		local name = self.name
		if (name) then
			table.insert( args, SERVER and self.colors.server or self.colors.client )
			table.insert( args, "[" .. name .. "]: " )
		end
	end

	table.insert( args, self.colors.white )

	-- Parsing args
	do
		if data.args then
			table.Add( args, data.args )
		end
	end

	-- delay (for timeLog)
	do
		if (data.delay) then
			table.insert( args, self.colors.gray )
			table.insert( args, " | " .. math.Round(data.delay * 1000, 1) .. " ms" )
		end
	end

	table.insert( args, "\n" )

	return args
end

--- Defines, should log or not
-- @param a level object
-- @return enable log or not
-- @see logger.levels
function logger:canLog( level )
	if not level then return true end

	local level_num
	for num, data in ipairs(self.levels) do
		if level[1] == data[1] then
			level_num = num
			break
		end
	end
	if not level_num then return true end

	local allowed_level_num = cvars.Number("gpm_level", 3)

	-- Returns true if log level lower, or equals to allowed
	return level_num <= allowed_level_num
end

---
-- @param params { level = {...}, args = {...}, delay = number }
-- @see logger:log
function logger:print( params )
	params.parsedLevel = self:getLevel( params.level )
	if not self:canLog( params.parsedLevel ) then return end

	local args = self:format( params )

	MsgC( unpack( args ) )
end

---
function logger:log(level, ...)
	self:print({ level = level, args = {...} })
end

-- function logger:print( level, message, ... )
-- 	local level = self:getLevel( level )
-- 	if not self:canLog( level ) then return end

-- 	local args = self:format({ level = level, message = message, args = {...} })

-- 	MsgC( unpack( args ) )
-- end

-- function logger:error( ... )
-- 	self:log("error", ...)
-- end

-- function logger:info( ... )
-- 	self:log("info", ...)
-- end

-- function logger:warn( ... )
-- 	self:log("warn", ...)
-- end

-- function logger:debug( ... )
-- 	self:log("debug", ...)
-- end

---
-- @usage local perf = logger:timeLog()
-- @usage perf:log("info", "Hello World!")
function logger:timeLog()
	local indexer = function(self, key)
		for _, t in ipairs(self.logger.levels) do
			if t[1] == key then
				self[key] = function(self, ...)
					return self:log(key, ...)
				end
	
				return self[key]
			end
		end
	end

	return setmetatable({
		logger = self,
		start_time = SysTime(),
		done = function(self, params)
			local logger = self.logger

			logger:print( table.Merge({ delay = SysTime() - self.start_time }, params) )
		end,
		log = function(self, level, ...)
			self:done({ level = level, args = {...} })
		end
	}, { __index = indexer })
end

--- Creates new logger from existing logger
-- @usage local my_logger = logger:inherit( "MyLogger" )
-- @param name
-- @return a logger
function logger:inherit( name )
	if not self.__index then
		self.__index = self
	end

	local new_logger = InheritClass( self )

	new_logger.name = name

	return new_logger
end

--- Creates new logger
-- Uses logger base as parent. To use custom logger as parent, use :inherit
-- @usage local my_logger = logger.new( "MyLogger" )
-- @see logger.inherit
function logger.new( ... )
	return logger:inherit( ... )
end

Logger = setmetatable({}, { __call = function(_, ...) return logger.new(...) end })
