local GPM = GPM
GPM.Loader = GPM.Loader or {}
GPM.Packages = GPM.Packages or {}
local Loader = GPM.Loader
local Packages = GPM.Packages

local log = GPM.Logger('GPM.Loader')

local function getPackagesPathsFromDir(root)
	local _, dirs = file.Find(GPM.Path(root, '*'), 'LUA')

	local packages = {}
	for _, dir in ipairs(dirs) do
		if file.Exists(GPM.Path(root, dir, 'package.lua'), 'LUA') then
			packages[#packages + 1] = GPM.Path(root, dir)
		end
	end
	return packages
end

local function getPackageFromPath(path)
	local err = 'package.lua not found'
	local func

	local packageLua = GPM.Path( path, 'package.lua' )
	if file.Exists(packageLua, 'LUA') then
		func = CompileFile( packageLua )
	end

	-- Send package.lua to client
	AddCSLuaFile( packageLua )

	if isstring( func ) then
		err = func
		func = nil
	end

	local package_info
	if func then
		-- Limiting function (package.lua file) enviroment
		setfenv(func, {})
		local ok, info = pcall(func)

		if ok then
			if istable( info ) then
				package_info = info
			else
				err = 'invalid info from package.lua (not is table)'
			end
		else
			err = 'package.lua not loadable'
		end
	end

	assert( package_info, err )

	package_info = func()
	package_info.name = package_info.name or path:GetFileFromFilename()
	package_info.root = path

	return GPM.Package(package_info)
end

local function resolveDependencies(pkg, packages)
	if not pkg.dependencies then return true end

	log:debug('resolving dependencies for package {1}', pkg)
	for name, rule in pairs(pkg.dependencies) do
		local dependency = Loader.FindPackage(name, packages)
		if not dependency then
			pkg.state = 'failed'
			log:error('dependency {1} not found for package {2}.', name, pkg)
			return false
		end

		-- Checking if found version of the dependency matches with rule
		if not (dependency.version % rule) then
			pkg.state = 'failed'
			log:error('dependency {1} not matches with package {2} specified version', dependency, pkg)
			return false
		end

		--Circular dependency protection
		if dependency.state == 'resolving' or dependency.state == 'running' then
			pkg.state = 'failed'
			log:error('package {1} dependency {2} already resolving or running. Maybe we have circular dependency', pkg, dependency)
			return false
		end

		local ok = Loader.ResolvePackage(dependency, packages)
		if not ok then
			pkg.state = 'failed'
			log:error('failed to resolve dependency {1} for package {2}', dependency, pkg)
			return false
		end
	end

	return true
end

local function resolvePeerDependencies(pkg, packages)
	if not pkg.peerDependencies then return true end

	log:debug('resolving peerDependencies for package {1}', pkg)
	for name, rule in pairs(pkg.peerDependencies) do
		local dependency = Loader.FindPackage(name, packages)
		if not dependency then -- Ignore if package not installed
			continue
		end

		-- Checking if found version of the dependency matches with rule
		if not (dependency.version % rule) then
			pkg.state = 'failed'
			log:error('peerDependency {1} not matches with package {2} specified version', dependency, pkg)
			return false
		end

		--Circular dependency protection
		if dependency.state == 'resolving' or dependency.state == 'running' then
			pkg.state = 'failed'
			log:error('package {1} peerDependency {2} already resolving or running. Maybe we have circular dependency', pkg, dependency)
			return false
		end

		local ok = Loader.ResolvePackage(dependency, packages)
		if not ok then
			pkg.state = 'failed'
			log:error('failed to resolve peerDependency {1} for package {2}', dependency, pkg)
			return false
		end
	end

	return true
end

local function resolveOptionalDependencies(pkg, packages)
	if not pkg.optionalDependencies then return true end

	log:debug('resolving optionalDependencies for package {1}', pkg)
	for name, rule in pairs(pkg.optionalDependencies) do
		local dependency = Loader.FindPackage(name, packages)
		if not dependency then -- ignore if package not found
			continue
		end

		-- Checking if found version of the dependency matches with rule
		if not (dependency.version % rule) then -- ignore if package not matches with specified version
			continue
		end

		--Circular dependency protection
		if dependency.state == 'resolving' or dependency.state == 'running' then
			pkg.state = 'failed'
			log:error('optionalDependency {2} of package {1} already resolving or running. Maybe we have circular dependency', pkg, dependency)
			return false
		end

		local ok = Loader.ResolvePackage(dependency, packages)
		if not ok then
			log:warn('optionalDependency {1} of package {2} found, but not resolved. Skipping...', dependency, pkg)
		end
	end

	return true
end

function Loader.FindPackage(name, packages)
	if not isstring(name) then return end

	if istable(packages) then
		for pkg_name, pkg_info in pairs(packages) do
			if pkg_name == name then
				log:debug('found package {1} in custom registry', pkg_info)
				return pkg_info
			end
		end
	end

	for pkg_name, pkg_info in pairs(Packages) do
		if pkg_name == name then
			log:debug('found package {1} in global registry', pkg_info)
			return pkg_info
		end
	end

	log:debug('package {1} not found', name)
end

function Loader.LoadPackages(root)
	local dirs = getPackagesPathsFromDir(root)
	local packages = {}

	for _, dir in ipairs(dirs) do
		local ok, package = xpcall(getPackageFromPath, function(err)
			log:error('failed to load package from "{1}":', dir)
			ErrorNoHaltWithStack(err)
		end, dir)

		if ok then
			packages[#packages + 1] = package
		end
	end

	return packages
end

function Loader.RunPackage(pkg)
	if not pkg.root then
		pkg.state = 'failed'
		log:error('package with unknown root? i do not know how to run package.')
		return false
	end

	local main = pkg.main or 'main.lua'
	local path
	if file.Exists(GPM.Path(pkg.root, main), 'LUA') then
		path = GPM.Path(pkg.root, main)
	elseif main ~= 'main.lua' and file.Exists(main, 'LUA') then
		path = main
	else
		pkg.state = 'failed'
		log:error('cannot find {1} package main "{2}" (file does not exist)', pkg, main)
		return false
	end

	if pkg.state ~= 'resolved' then
		log:warn('package {1} not resolved, some dependencies may be missed.', pkg)
	end

	pkg.state = 'running'

	PKG = pkg

	local ok, err = GPM.SH( path )

	PKG = nil

	if not ok then
		pkg.state = 'failed'
		log:error('{1} package run error:\n{2}', pkg, err)
		return false
	end

	pkg.state = 'started'
	return true
end

function Loader.ResolvePackage(pkg, packages)
	if pkg.state == 'loaded' then
		log:debug('package {1} already loaded.', pkg)
		return true
	end

	pkg.state = 'resolving'
	local ok =
		resolveDependencies(pkg, packages) and
		resolvePeerDependencies(pkg, packages) and
		resolveOptionalDependencies(pkg, packages)

	if not ok then
		pkg.state = 'failed'
		log:error('failed to resolve dependencies of {1} package', pkg)
		return false
	end

	pkg.state = 'resolved'
	ok = Loader.RunPackage(pkg)
	if ok then
		pkg.state = 'loaded'
		log:info('{1} loaded.', pkg)
	end
	return ok
end

function Loader.ResolvePackages(packages, noRegister)
	GPM.CheckType(packages, 1, 'table', 3)

	-- Adding packages to registry
	local registry = not noRegister and Packages or {}
	for _, pkg in ipairs(packages) do
		if registry[pkg.name] then
			log:warn('Package {1} already existing. Replacing with new package {2}.', registry[pkg.name], pkg)
		end

		registry[pkg.name] = pkg
	end

	for _, pkg in ipairs(packages) do
		Loader.ResolvePackage(pkg, noRegister and registry)
	end
end

function Loader.ResolvePackagesFromDir(root, noRegister)
	GPM.CheckType(root, 1, 'string', 3)
	log:info('Resolving packages from "{1}"...', root)

	local packages = Loader.LoadPackages(root)
	return Loader.ResolvePackages(packages, noRegister)
end
