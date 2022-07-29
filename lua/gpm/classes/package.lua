
module( "GPM", package.seeall )

local logger = Logger("GPM.Package")

--[[ 

	- Structure of package

	name: string|nil - Name of package
	version: string|nil - Version of package
	path: string|nil - Local path to package
	state: State - State of package (see more info below)
	metadata: Metadata|nil - Metadata of package (see more info below)
	loader: Loader|nil - Loader. Must present to load package

	- States

	1. "unloaded" - Package just created, and didn't loaded. 
	                At this state package doesn't have metadata, 
	                and maybe don't have name and version
	
	2. "failed" - When package failed some task (loading metadata, or loading runtime scripts)
	
	3. "preparing" - Package loading it metadata, 
	                 only can be caught when metadata loading just started

	4. "ready" - Package ready to load. (metadata must be loaded at this point)
	

	If package state is nil, then this package is invalid
--]]

local package = CreateClass( "Package" )

function package:__tostring()
	return ("Package %s@%s"):format( tostring(self.name), tostring(self.version) )
end

function package:_failed( reason )
	self.state = "failed"
	self.error = reason
end

function package:setLoader( loader )
	self.loader = loader
end

function package:setLocalLoader()
	self:setLoader( GetLoader("LocalLoader") )
end

function package:loadMetadata()
	if not self.loader then error("Invalid loader") end

	self.state = "preparing"

	local ok, metadata = pcall(self.loader.loadMetadata, self)

	if not ok or not metadata then
		self:_failed( metadata or "can't load metadata" )
		return
	end

	self.metadata = metadata
	self.state = "ready"
end

function package.new( name, version, path )
	local pkg = InheritClass( package )

	pkg.name = nil
	pkg.version = nil
	pkg.path = nil
	pkg.state = "unloaded"
	pkg.metadata = PackageMetadata()
	pkg.loader = nil

	pkg.metadata:parseMetadata({
		name = name,
		version = version and tostring(version),
	})

	while pkg.metadata:hasErrors() do
		local err = pkg.metadata:popError()

		logger:warn(format( "failed to parse field {0}: {1}", err.field, err.reason ))
	end

	pkg.name = pkg.metadata.name
	pkg.version = pkg.metadata.version

	return pkg
end

Package = setmetatable({}, { __call = function(_, ...) return package.new(...) end })

Package.Packages = Package.Packages or {}
local packages = Package.Packages
local local_packages = {}

function Package.getPackage( name, version )
	if istable( packages[name] ) then 
		return packages[name][version]
	end
end

function Package.savePackage( pkg )
	if pkg.state == "unloaded" then error("Invalid package state (unloaded)") end

	if not packages[pkg.name] then
		packages[pkg.name] = {}
	end

	packages[pkg.name][pkg.version] = pkg
end

function Package.removePackage( pkg )
	if pkg.state == "unloaded" then error("Invalid package state (unloaded)") end

	if Package.getPackage( pkg.name, pkg.version ) then
		packages[pkg.name][pkg.version] = nil
	end
end

function Package.getLocalPackage( name )
	if local_packages[name] then return local_packages[name] end

	if istable( packages[name] ) then
		for _, pkg in pairs( packages[name] ) do
			if IsLocalLoader( pkg.loader ) then
				local_packages[name] = pkg

				return pkg
			end
		end
	end

	local pkg = Package( name )

	pkg:setLocalLoader()

	local path = pkg.loader.findPackage( pkg.name )

	if path then
		pkg.path = path

		return pkg
	end
end

if CLIENT then return end

NextTick(function()
	print("\n\n---- " .. tostring(CurTime()) .. " ----")

	local pkg = Package.getLocalPackage( "my_test" )
	
	if pkg then
		print("PKG!")
	
		pkg:loadMetadata()
	
		PrintTable(pkg)
	end
end)
