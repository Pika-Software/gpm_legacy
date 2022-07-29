
module( "GPM", package.seeall )

local schema = CreateClass("Schema")

-- function schema:__index( key )
-- 	return Either( self.fields[key] ~= nil, self.fields[key], schema[key] )
-- end

--- Creates error object from passed arguments
-- @param field string. Like "my_field" or "my_table.my_field"
-- @param reason why validating didn't passed
-- @return error object - { field = "...", reason = "..." }
function schema.create_error( field, reason )
	return {
		field = field,
		reason = reason,
	}
end

--- Pushes error object in error stack.
-- @param error object
-- @see schema.create_error
function schema:push_error( err )
	table.insert( self.errors, err )
end

function schema:pop_error()
	return table.remove( self.errors, 1 )
end

function schema:error_count()
	return #self.errors
end

function schema:has_errors()
	return self:error_count() ~= 0
end

--- Alias to Rule:validate
--  maybe later will upgraded, for more functionality
-- @see Rule.validate
-- @param value
-- @param rule
-- @return true if value successfully validates, otherwise false
-- @return error string, if validation failed
function schema:validate_field( value, rule )
	return rule:validate( value )
end

--- Validates a table with specified rules
--  and returns table with fields and errors
--  { fields = {...}, errors = {...} }
-- @param table to validate
-- @param rules - { a = Rule(...), b = Rule(...) }
-- @return table with fields and errors
function schema:validate_table(tbl, rules)
	CheckType(tbl, 1, "table")

	local result = {
		fields = {},
		errors = {},
	}

	for key, rule in pairs(rules) do
		local value = tbl[key]

		-- Validating subtable with subrules
		if istable(rule) and not IsRule(rule) then
			if istable(value) then
				local rules = rule[key]
				result.fields[key] = self:validate_table(value, rules)
			else
				result.errors[key] = "expected table, got " .. type(value)
			end

			continue
		end

		local ok, err = self:validate_field( value, rule )

		if ok then
			self.fields[key] = value
		else
			self.errors[key] = err
		end
	end

	return result
end


--- Validates a table, with rules specified in .new(...)
--  same as schema.validate_table, but uses inner rules
-- @see schema.new
-- @see schema.validate_table
-- @param table to validate
-- @return table with fields and errors, or nil if given value isn't table
function schema:validate_raw(tbl)
	if not istable( tbl ) then return end

	return self:validate_table( tbl, self.rules )
end

--- Validates a table, with rules specified in .new(...)
--  also pushes errors in inner error stack.
--  to use error stack, see methods above.
-- @see schema.new
-- @param table to validate
-- @return table with validated values
function schema:validate(tbl)
	if not istable( tbl ) then return end

	return self:validate_table( tbl, self.rules )
end

function schema.new(rules)
	CheckType(rules, 1, "table", 4)

	local new_schema = InheritClass( schema )

	new_schema.errors = {}
	//new_schema.fields = {}
	new_schema.rules = rules

	return new_schema
end

Schema = setmetatable({}, { __call = function(_, ...) return schema.new(...) end })