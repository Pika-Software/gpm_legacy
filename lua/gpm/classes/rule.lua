
module( "GPM", package.seeall )

local rule = CreateClass("Rule")

function rule:validateRequired( value )
	if self.valueRequired == false then return true end

	return value ~= nil and value ~= ""
end

function rule:validateType( value )
	if value == nil then return true end

	if isstring( self.valueType ) then
		return type( value ) == self.valueType
	end

	return table.HasValue( self.valueType, type(value) )
end

function rule:validateLength( value )
	if value == nil then return true end

	local length = isnumber(value) and value or #value

	if isnumber(self.valueLength) then
		return length == self.valueLength
	end

	local min = self.valueLength.min
	local max = self.valueLength.max

	if min and length < min then return false end
	if max and length > max then return false end
	return true
end

function rule:validateEnum( value )
	if value == nil then return true end

	return table.HasValue( self.valueEnum, value )
end

function rule:validateMatch( value )
	if value == nil then return true end

	return string.match( value, self.valuePattern ) ~= nil
end

function rule:validateValidator( value )
	if value == nil then return true end

	return self.valueValidator( value )
end

--- Weird thing
function rule:validate( value )
	if not self:validateRequired( value ) then return false end

	if self.valueType and not self:validateType( value ) then return false end
	if self.valueLength and not self:validateLength( value ) then return false end
	if self.valueEnum and not self:validateEnum( value ) then return false end
	if self.valuePattern and not self:validateMatch( value ) then return false end
	if self.valueValidator and not self:validateValidator( value ) then return false end

	return true
end

--- Creates new rule
-- list of available options: 
--		required: bool -- checks if value is not nil or empty string
--		type: string -- checks if type equals to given type
--		length: number | { min: number, max: number } -- checks if length (or number) are equal to number, or in range
--		enum: { ...any } -- checks if value exists in this enum
--		match: Pattern -- Checks if string matches pattern. See https://wiki.facepunch.com/gmod/Patterns
--		validator: function -- Custom validator function. Should accept any value and return boolean
--
-- @param table of options
function rule.new( options )
	local new_rule = InheritClass( rule )

	if isbool( options.required ) then
		new_rule.valueRequired = options.required
	end

	if isstring( options.type ) or istable( options.type ) then
		new_rule.valueType = options.type
	end

	if isnumber( options.length ) or istable( options.length ) then
		new_rule.valueLength = options.length
	end

	if istable( options.enum ) then
		new_rule.valueEnum = options.enum
	end

	if isstring( options.match ) then
		new_rule.valuePattern = options.match
	end

	if isfunction( options.validator ) then
		new_rule.valueValidator = options.validator
	end

	return new_rule
end

Rule = setmetatable({}, { __call = function(_, ...) return rule.new(...) end })
