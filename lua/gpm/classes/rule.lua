
module( "GPM", package.seeall )

local function getValueLength( value )
	return isnumber(value) and value or #value
end

local rule = CreateClass("Rule")

rule.option_validators = {
	["required"] 	= function( value ) return isbool( value ) 							end,
	["type"] 		= function( value ) return isstring( value ) or istable( value ) 	end,
	["length"] 		= function( value ) return isnumber( value ) or istable( value ) 	end,
	["enum"] 		= function( value ) return istable( value ) 						end,
	["match"] 		= function( value ) return isstring( value ) 						end,
	["validator"]	= function( value ) return isfunction( value ) 						end
}

rule.validators = {
	["required"] = function( value, options )
		if options.required == false then return true end

		return value ~= nil and value ~= ""
	end,

	["type"] = function( value, options )
		if value == nil then return true end

		-- value_type can be string or table
		if isstring( options.type ) then
			return type( value ) == options.type
		end
	
		return table.HasValue( options.type, type(value) )
	end,

	["length"] = function( value, options )
		if value == nil then return true end

		local length = getValueLength( value )
	
		if isnumber(options.length) then
			return options.length == length
		end
	
		local min = options.length.min
		local max = options.length.max

		if min and length < min then return false end
		if max and length > max then return false end
		return true
	end,

	["enum"] = function( value, options )
		if value == nil then return true end

		return table.HasValue( options.enum, value )
	end,

	["match"] = function( value, options )
		if value == nil then return true end

		return string.match( value, options.match ) ~= nil
	end,

	["validator"] = function( value, options )
		if value == nil then return true end

		return options.validator( value )
	end,
}

rule.messages = {
	["required"] = "required",

	["type"] = function( value, options )
		local expected = istable( options.type ) and table.concat( options.type, " or " ) or options.type

		return format("expected {0} type, got {1}", expected, type(value))
	end,

	["length"] = function( value, options )
		local length = getValueLength( value )

		if isnumber( options.length ) then
			return format("expected length {0}, got {1}", options.length, length)
		end

		local min = options.length.min and "> " .. options.length.min
		local max = options.length.max and "< " .. options.length.max

		return format("expected length {0}, got {1}", table.concat({min, max}, " and "), length)
	end,

	["enum"] = function( value, options )
		local enum = {}
		for _, v in ipairs(options.enum) do
			table.insert(enum, ValueToString(v))
		end

		return format("expected value from [{0}]", table.concat(enum, ", "))
	end,

	["match"] = function( value, options )
		return format("the value isn't matching pattern '{1}'", value, options.match)
	end,

	["validator"] = "the value didn't passed a custom validator"
}

function rule:validate( value )
	for key, validate in pairs( self.validators ) do
		if self.options[key] ~= nil then
			local ok = validate( value, self.options )

			if not ok then
				-- That's looking messy
				local message = isfunction( self.messages[key] ) and
					self.messages[key]( value, self.options ) or -- Get message from function
					isstring( self.messages[key] ) and self.messages[key] -- Message from string

				if message then
					return false, format("invalid value '{0}' ({1})", value, message)
				end

				return false, format("invalid value '{0}' (failed when validating '{1}')", value, key)
			end
		end
	end

	return true
end

--- Creates new rule
-- list of available options: 
--		required: bool -- checks if value is not nil or empty string
--		type: string | { ...string } -- checks if type equals to given type
--		length: number | { min: number, max: number } -- checks if length (or number) are equal to number, or in range
--		enum: { ...any } -- checks if value exists in this enum
--		match: Pattern -- Checks if string matches pattern. See https://wiki.facepunch.com/gmod/Patterns
--		validator: function -- Custom validator function. Should accept any value and return boolean
--
-- @param table of options
function rule.new( options )
	local new_rule = InheritClass( rule )

	new_rule.options = {}

	-- Here we parsing options
	for key, validate in pairs( new_rule.option_validators ) do -- Getting every option validator
		local value = options[key] -- Getting value from options

		if validate( value ) then -- Checking if value from options satisfies our requirements (sounds weird)
			new_rule.options[key] = value
		end
	end

	return new_rule
end

Rule = setmetatable({}, { __call = function(_, ...) return rule.new(...) end })

--- Checks if given value are Rule
function IsRule( rule )
	return istable(rule) and rule.Name == "Rule"
end

-- Rule tests. Works only in development.
if IsDevelopment() then
	local test_rule

	test_rule = Rule({ required = true, type = "string" })
	assert( test_rule:validate("Hello") == true )
	assert( test_rule:validate( nil ) == false )
	assert( test_rule:validate( 1 ) == false )

	print( test_rule:validate( 1 ) )

	test_rule = Rule({ required = false, type = { "table", "number" } })
	assert( test_rule:validate( {} ) == true )
	assert( test_rule:validate( nil ) == true )
	assert( test_rule:validate( 1 ) == true )
	assert( test_rule:validate( "str" ) == false )

	test_rule = Rule({ length = 1 })
	assert( test_rule:validate( { "value" } ) == true )
	assert( test_rule:validate( 1 ) == true )
	assert( test_rule:validate( "g" ) == true )
	assert( test_rule:validate( "good" ) == false )
	assert( test_rule:validate( 3 ) == false )

	test_rule = Rule({ length = { min = 1, max = 3 } })
	assert( test_rule:validate( { "value" } ) == true )
	assert( test_rule:validate( 5 ) == false )
	assert( test_rule:validate( "hello world" ) == false )
	assert( test_rule:validate( "wrd" ) == true )
	assert( test_rule:validate( 2 ) == true )

	test_rule = Rule({ enum = { "hello", "world" } })
	assert( test_rule:validate( "hello" ) == true )
	assert( test_rule:validate( "world" ) == true )
	assert( test_rule:validate( "hello world" ) == false )

	test_rule = Rule({ match = "^[%d]+$" })
	assert( test_rule:validate( "string" ) == false )
	assert( test_rule:validate( "123" ) == true )
	assert( test_rule:validate( 9 ) == true )
	assert( test_rule:validate( "-123" ) == false )

	test_rule = Rule({ validator = function( value, opts ) return not value end })
	assert( test_rule:validate( "string" ) == false )
	assert( test_rule:validate( 7632 ) == false )
	assert( test_rule:validate( nil ) == true )
	assert( test_rule:validate( false ) == true )
end

