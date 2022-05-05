module( "GPM", package.seeall )

local file_Exists = file.Exists
local type = type

Loader = Loader or {}
Packages = Packages or {}

do

	local log = Logger( 'GPM' )
	concommand.Add("gpm_list", function()
		for name, package in pairs( Packages ) do
			log:info( "{1} - {2}", package, package.description == "" and "No Description" or package.description )
		end
	end)

end


local log = Logger( 'GPM.Loader' )

do

	local ErrorNoHaltWithStack = ErrorNoHaltWithStack
	local table_insert = table.insert
	local file_Find = file.Find
	local xpcall = xpcall
	local ipairs = ipairs

	local function getPackagesPathsFromDir( root )
		local files, dirs = file_Find( Path( root, '*' ), 'LUA' )

		local packages = {}
		for num, dir in ipairs( dirs ) do
			if file_Exists( Path( root, dir, 'package.lua' ), 'LUA' ) then
				table_insert( packages, Path( root, dir ) )
			end
		end

		return packages
	end

	local getPackageFromPath

	do

		local AddCSLuaFile = AddCSLuaFile
		local CompileFile = CompileFile
		local setfenv = setfenv
		local assert = assert
		local Error = Error
		local pairs = pairs

		function getPackageFromPath( path )
			local packageName = path:GetFileFromFilename()
			local filename = Path( path, 'package.lua' )
			if file_Exists( filename, "LUA" ) then
				assert( CLIENT or file.Size( filename, "LUA" ) > 0, filename .. " is empty!" )

				if (CLIENT) and (package.onlyserver ~= true) then
					return
				end

				if (SERVER) then

					AddCSLuaFile( filename )

					if (package.onlyclient == true) then
						return
					end

				end

				local func = CompileFile( filename )
				assert( type( func ) == "function", "Attempt to compile package " .. packageName .. " failed!" )

				local env = {}
				setfenv( func, env )

				local ok, data = pcall( func )
				if (ok) then
					local package = {}
					if type( data ) == "table" then
						package = data
					else
						package = env
					end

					for key, value in pairs( package ) do
						package[ key:lower() ] = value
					end

					package.name = package.name or packageName
					package.root = path

					return Package( package )
				end

				Error( "Package '" .. packageName .. "' сontains an error!" )
			end

			Error( filename .. " not found!" )
		end

	end

	do

		local roots = {}
		function Loader.Root( path )
			table_insert( roots, path )
		end

		local table_Merge = table.Merge
		function Loader.LoadPackages( root )
			local dirs = {}
			local packages = {}

			if (root == nil) then
				for num, root in ipairs( roots ) do
					log:info( 'Resolving packages from "{1}"...', root )
					dirs = table_Merge( dirs, getPackagesPathsFromDir( root ) )
				end
			else
				log:info( 'Resolving packages from "{1}"...', root )
				dirs = getPackagesPathsFromDir( root )
			end

			for num, dir in ipairs( dirs ) do
				local ok, package = xpcall( getPackageFromPath, function( err )
					log:error( 'failed to load package from "{1}":', dir )
					ErrorNoHaltWithStack( err )
				end, dir )

				if ok then
					table_insert( packages, package )
				end
			end

			return packages
		end

	end

	function Loader.ResolvePackages( packages, noRegister )
		CheckType( packages, 1, 'table', 3 )

		-- Adding packages to registry
		local registry = not noRegister and Packages or {}
		for num, pkg in ipairs( packages ) do
			if registry[ pkg.name ] then
				log:warn( 'Package {1} already existing. Replacing with new package {2}.', registry[ pkg.name ], pkg )
			end

			registry[ pkg.name ] = pkg
		end

		for num, pkg in ipairs( packages ) do
			Loader.ResolvePackage( pkg, noRegister and registry )
		end
	end

end

local resolveDependencies
local resolvePeerDependencies
local resolveOptionalDependencies

do

	local pairs = pairs

	function resolveDependencies( pkg, packages )
		if not pkg.dependencies then return true end

		log:debug( 'resolving dependencies for package {1}', pkg )
		for name, rule in pairs( pkg.dependencies ) do
			local dependency = Loader.FindPackage( name, packages )
			if not dependency then
				pkg.state = 'failed'
				log:error( 'dependency {1} not found for package {2}.', name, pkg )
				return false
			end

			-- Checking if found version of the dependency matches with rule
			if not (dependency.version % rule) then
				pkg.state = 'failed'
				log:error( 'dependency {1} not matches with package {2} specified version', dependency, pkg )
				return false
			end

			--Circular dependency protection
			if (dependency.state == 'resolving') or (dependency.state == 'running') then
				pkg.state = 'failed'
				log:error( 'package {1} dependency {2} already resolving or running. Maybe we have circular dependency', pkg, dependency )
				return false
			end

			local ok = Loader.ResolvePackage( dependency, packages )
			if not ok then
				pkg.state = 'failed'
				log:error( 'failed to resolve dependency {1} for package {2}', dependency, pkg )
				return false
			end
		end

		return true
	end

	function resolvePeerDependencies(pkg, packages)
		if not pkg.peerDependencies then return true end

		log:debug( 'resolving peerDependencies for package {1}', pkg )
		for name, rule in pairs( pkg.peerDependencies ) do
			local dependency = Loader.FindPackage( name, packages )
			if not dependency then -- Ignore if package not installed
				continue
			end

			-- Checking if found version of the dependency matches with rule
			if not (dependency.version % rule) then
				pkg.state = 'failed'
				log:error( 'peerDependency {1} not matches with package {2} specified version', dependency, pkg )
				return false
			end

			--Circular dependency protection
			if (dependency.state == 'resolving') or (dependency.state == 'running') then
				pkg.state = 'failed'
				log:error( 'package {1} peerDependency {2} already resolving or running. Maybe we have circular dependency', pkg, dependency )
				return false
			end

			local ok = Loader.ResolvePackage( dependency, packages )
			if not ok then
				pkg.state = 'failed'
				log:error( 'failed to resolve peerDependency {1} for package {2}', dependency, pkg )
				return false
			end
		end

		return true
	end

	function resolveOptionalDependencies(pkg, packages)
		if not pkg.optionalDependencies then return true end

		log:debug( 'resolving optionalDependencies for package {1}', pkg )
		for name, rule in pairs( pkg.optionalDependencies ) do
			local dependency = Loader.FindPackage( name, packages )
			if not dependency then -- ignore if package not found
				continue
			end

			-- Checking if found version of the dependency matches with rule
			if not (dependency.version % rule) then -- ignore if package not matches with specified version
				continue
			end

			--Circular dependency protection
			if (dependency.state == 'resolving') or (dependency.state == 'running') then
				pkg.state = 'failed'
				log:error( 'optionalDependency {2} of package {1} already resolving or running. Maybe we have circular dependency', pkg, dependency )
				return false
			end

			local ok = Loader.ResolvePackage( dependency, packages )
			if not ok then
				log:warn( 'optionalDependency {1} of package {2} found, but not resolved. Skipping...', dependency, pkg )
			end
		end

		return true
	end

	function Loader.FindPackage( name, packages )
		if type( name ) ~= "string" then return end

		if type( packages ) == "table" then
			for pkg_name, pkg_info in pairs( packages ) do
				if (pkg_name == name) then
					log:debug( 'found package {1} in custom registry', pkg_info )
					return pkg_info
				end
			end
		end

		for pkg_name, pkg_info in pairs( Packages ) do
			if (pkg_name == name) then
				log:debug( 'found package {1} in global registry', pkg_info )
				return pkg_info
			end
		end

		log:debug( 'package {1} not found', name )
	end

end

function Loader.RunPackage( pkg )
	if not pkg.root then
		pkg.state = 'failed'
		log:error( 'package with unknown root? i do not know how to run package.' )
		return false
	end

	local main = pkg.main or 'main.lua'
	local path
	if file_Exists( Path( pkg.root, main ), 'LUA' ) then
		path = Path( pkg.root, main )
	elseif (main ~= 'main.lua') and file_Exists( main, 'LUA' ) then
		path = main
	else
		pkg.state = 'failed'
		log:error( 'cannot find {1} package main "{2}" (file does not exist)', pkg, main )
		return false
	end

	if (pkg.state ~= 'resolved') then
		log:warn( 'package {1} not resolved, some dependencies may be missed.', pkg )
	end

	pkg.state = 'running'

	-- PrintTable( pkg )

	local ok, err = false, nil
	if (pkg.onlyserver == true) then
		ok, err = SV( path )
	elseif (pkg.onlyclient == true) then
		ok, err = CL( path )
	else
		ok, err = SH( path )
	end

	if not ok then
		pkg.state = 'failed'
		log:error( '{1} package run error:\n{2}', pkg, err )
		return false
	end

	pkg.state = 'started'
	return true
end

function Loader.ResolvePackage( pkg, packages )
	if (pkg.state == 'loaded') then
		log:debug( 'package {1} already loaded.', pkg )
		return true
	end

	if (pkg.onlyserver == true) and (CLIENT) then
		return
	end

	pkg.state = 'resolving'
	local ok = resolveDependencies( pkg, packages ) and
			resolvePeerDependencies( pkg, packages ) and
			resolveOptionalDependencies( pkg, packages )

	if not ok then
		pkg.state = 'failed'
		log:error( 'failed to resolve dependencies of {1} package', pkg )
		return false
	end

	pkg.state = 'resolved'
	ok = Loader.RunPackage( pkg )
	if (ok) then
		pkg.state = 'loaded'
		log:info( '{1} loaded.', pkg )
	end

	return ok
end

function Loader.ResolveAllPackages( noRegister )
	return Loader.ResolvePackages( Loader.LoadPackages(), noRegister )
end
