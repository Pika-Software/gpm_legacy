--- Helpers for many things
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

--- Throws "Not Implemented" error.
function NotImplementedError()
	error("This feature is not implemented.")
end

--- Converts package name and version
-- @param name of package, can be also be package
-- @param version of package
-- @return a package id (string)
function ConvertPackageToID( name, version )
	-- @todo
	if --[[ isPackage ]] false then
		return ConvertPackageToID( name.name, name.version )
	end

	return tostring(name) .. "@" .. tostring(version)
end

--- Converts package id to name and version
-- @param id of package
-- @return a package name, a package version
function ConvertIDToPackage( id )
	local name, version = string.match(id, "([%w_-]+)@(.+)")

	return name, version
end

--- Checks if given path is directory
-- Sometimes client-side fails to determine if directory exists
-- This functions should help with this bug
-- @see https://github.com/Facepunch/garrysmod-issues/issues/1038
--
-- @param path to directory
-- @param gamePath GAME, LUA and etc.
-- @return true if directory exists
function IsDir( path, gamePath )
	if not isstring(path) or not isstring(gamePath) then return false end

	-- On server-side everything work fine
	if SERVER then
		return file.IsDir( path, gamePath )
	end

	-- Adding wildcard to the end of path, so file.Find hack will work
	-- path/to/dir -> path/to/dir*
	local folders = select(2, file.Find( path .. "*", gamePath ))

	-- If nothing found, directory isn't exists
	if not folders or not folders[1] then return false end

	return string.EndsWith( path, folders[1] )
end