module( 'GPM', package.seeall )

Version = '2.2.2'

local type = type

do

	local debug_getinfo = debug.getinfo
	local error = error

	function CheckType( value, narg, tname, errorlevel )
		if type( value ) == tname then return end

		local dinfo = debug_getinfo( 2, 'n' )
		local fname = dinfo and dinfo.name or 'func'
		local serror = ('bad argument #%d to \'%s\' (%s expected, got %s)'):format( narg, fname, tname, type( value ) )

		error(serror, errorlevel or 2)
	end

end

do

	local table_insert = table.insert
	local table_concat = table.concat

	function Path( ... )
		local args = {...}

		local buffer = {}
		for i = 1, #args do
			local str = args[i]
			if type( str ) == 'string' then
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

	function SafeInclude( filename )
		CheckType(filename, 1, 'string', 3)

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

function SV( filename, dir )
	if CLIENT then return end
	CheckType(filename, 1, 'string', 3)
	return SafeInclude( Path( dir, filename ) )
end

do

	local AddCSLuaFile = AddCSLuaFile

	function CL( filename, dir )
		CheckType( filename, 1, 'string', 3 )
		local path = Path( dir, filename )

		if (SERVER) then
			AddCSLuaFile( path )
		else
			return SafeInclude( path )
		end
	end

	function SH( filename, dir )
		CheckType( filename, 1, 'string', 3 )
		local path = Path( dir, filename )

		if (SERVER) then
			AddCSLuaFile( path )
		end

		return SafeInclude( path )
	end

end

-- Include Me :)
SH('sh_logger.lua', 'gpm')
SH('sh_semver.lua', 'gpm')
SH('sh_author.lua', 'gpm')
SH('sh_package.lua', 'gpm')
SH('sh_loader.lua', 'gpm')

-- Packages Loading
Loader.Root( 'gpm/packages' )
Loader.Root( 'packages' )
Loader.ResolveAllPackages()