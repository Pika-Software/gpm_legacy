local type = type

GPM = GPM or {}
local GPM = GPM

do

	local debug_getinfo = debug.getinfo
	local error = error

	function GPM.CheckType( value, narg, tname, errorlevel )
		if type(value) == tname then return end

		local dinfo = debug_getinfo( 2, 'n' )
		local fname = dinfo and dinfo.name or 'func'
		local serror = ('bad argument #%d to \'%s\' (%s expected, got %s)'):format( narg, fname, tname, type( value ) )

		error(serror, errorlevel or 2)
	end

end

do

	local table_insert = table.insert
	local table_concat = table.concat

	function GPM.Path( ... )
		local args = {...}

		local buffer = {}
		for i = 1, #args do
			local str = args[i]
			if type( str ) == "string" then
				table_insert( buffer, str )
			end
		end

		if (#buffer == 0) then
			return nil
		end

		return table_concat( buffer, '/' )
	end

end

do

	local debug_getregistry = debug.getregistry
	local include = include
	local unpack = unpack

	function GPM.SafeInclude( filename )
		GPM.CheckType(filename, 1, 'string', 3)

		local errorhandler = debug_getregistry()[1]
		local lasterr
		debug_getregistry()[1] = function(err)
			lasterr = err
			return errorhandler(err)
		end

		local args = { include( filename ) }
		debug_getregistry()[1] = errorhandler

		return lasterr == nil, lasterr or unpack(args)
	end

end

function GPM.SV( filename, dir )
	if CLIENT then return end
	GPM.CheckType(filename, 1, 'string', 3)
	return GPM.SafeInclude( GPM.Path( dir, filename ) )
end

do

	local AddCSLuaFile = AddCSLuaFile

	function GPM.CL( filename, dir )
		GPM.CheckType( filename, 1, 'string', 3 )
		local path = GPM.Path( dir, filename )

		if SERVER then
			AddCSLuaFile( path )
		else
			return GPM.SafeInclude( path )
		end
	end

	function GPM.SH( filename, dir )
		GPM.CheckType( filename, 1, 'string', 3 )
		local path = GPM.Path( dir, filename )

		if SERVER then
			AddCSLuaFile( path )
		end

		return GPM.SafeInclude( path )
	end

end

GPM.SH('sh_include.lua', 'gpm')
GPM.Loader.ResolvePackagesFromDir('gpm/packages')
GPM.Loader.ResolvePackagesFromDir('packages')
