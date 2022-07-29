
module( "GPM", package.seeall )

local log = Logger("GPM.LocalLoader")

local localLoader = CreateLoader("LocalLoader")

--[[
function localLoader.getLocalPath(id)
	return Resolver.findLocalPackage( id )
end

--- Returns if package is valid or not
-- @param id of a package
-- @return true if valid, otherwise false
function localLoader.isValid(id)
	NotImplementedError()
end


--- Returns if package ready to load
-- Mostly used to indicated, if package downloaded or not
-- @param id of a package
-- @return true if ready, otherwise false
function localLoader.isReady(id)
	return true
end

--- Loads metadata from package
-- @param id of a package
-- @return a package metadata in table.
function localLoader.loadMetadata(id)
	local path = localLoader.getLocalPath(id)

	if SERVER then
		AddCSLuaFile(Path( path, "package.lua" ))
	end
end

--]]

--- There located all paths, where local packages located
-- @see localLoader.addLocalPath
localLoader.localPaths = localLoader.localPaths or {}

--- Adds path to list, where local packages located
-- @param path
function localLoader.addLocalPath( path )
	if not table.HasValue( localLoader.localPaths, path ) then
		table.insert( localLoader.localPaths, path )
		localLoader.clearCache()
	end
end

localLoader.cachedPaths = localLoader.cachedPaths or {}
--- Clears cache, what contains paths to found local packages
function localLoader.clearCache()
	table.Empty( localLoader.cachedPaths )
end

--- Finds local package from local paths
-- @return path to package if found, otherwise nil
function localLoader.findPackage( name )
	if not name then return nil end
	if localLoader.cachedPaths[name] then return localLoader.cachedPaths[name] end

	for _, dir in ipairs(localLoader.localPaths) do
		local path = Path( dir, name )

		if IsDir( path, "LUA" ) and file.Exists( Path(path, "package.lua"), "LUA" ) then
			log:debug("Found local package: ", log.colors.yellow, name)

			localLoader.cachedPaths[name] = path
			return path
		end
	end

	return nil
end

--- Returns if package ready to load
-- Mostly used to indicated, if package downloaded or not
-- @param path to a package
-- @return true if ready, otherwise false
function localLoader.isReady( pkg )
	return true
end

---
function localLoader.prepare( pkg )
	return true
end

function localLoader.loadMetadata( pkg )
	if not pkg.path then error("Create local package with Package.getLocalPackage") end
	if not localLoader.isReady( pkg ) then error() end
	local entry = Path( pkg.path, "package.lua" )

	local env = {}
	local load = setfenv( CompileFile(entry), env )

	-- Error handling?
	load()

	if pkg.name and env.name ~= pkg.name then
		error("Different package and local folder name.")
	end

	if SERVER then
		AddCSLuaFile( entry )
	end

	return env
end

function IsLocalLoader( loader )
	return loader == localLoader
end

-- Adding paths for local packages
hook.Add( "GPM.InitializePaths", "GPM.LocalLoader", function()
	table.Empty( localLoader.localPaths )
	localLoader.addLocalPath( "gpm/packages" )
	localLoader.addLocalPath( "packages" )
end)
