module( "GPM", package.seeall )

--- Packs varargs to table
-- @treturn { ..., n = lenght } table of args with parameter n, that equals varargs lenght
-- @see unpackArgs
function PackArgs(...)
	local len = select("#", ...)
	local args = { ... }

	args.n = len

	return args
end

--- Unpacks table to varargs
-- @param args a table
-- @return varargs
-- @see unpackArgs
function UnpackArgs(args, startIndex, endIndex)
	if not istable(args) then return args end
	return unpack(args, startIndex or 1, endIndex or args.n)
end

--- Converts value to string
-- if string, returns "string"
-- else tostring(value)
-- @param any value
-- @return string representation of value
function ValueToString(value)
	if isstring(value) then
		return ('"%s"'):format(value)
	end

	return util.TypeToString(value)
end

--- Runs given function in next tick
-- @param func
function NextTick(func)
	timer.Simple(0, func)
end
