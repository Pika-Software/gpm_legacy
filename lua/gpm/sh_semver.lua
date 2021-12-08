local GPM = GPM
GPM.Semver = GPM.Semver or {}

local function isValidNumber(num) -- number must be a positive and integer
	return num >= 0 and math.floor(num) == num
end

local function parsePreleaseAndBuildmeta(prerelease_and_buildmeta)
	
end

local function parseVersion(ver)
	local major, minor, patch, prerelease_and_buildmeta = string.match(ver, '^(%d+)%.?(%d*)%.?(%d*)(.-)$')
	if type(major) ~= 'string' then return end
	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
	local prelease, buildmeta = parsePreleaseAndBuildmeta(prerelease_and_buildmeta)
	return major, minor, patch, prelease, buildmeta
end

local mt = {}
function mt.new(major, minor, patch, prerelease, buildmeta)
	if not major then return end -- At least one parameter is needed

	if type(major) == 'string' then
		major, minor, patch, prerelease, buildmeta = parseVersion(ver)
	end
	minor = minor or 0
	patch = patch or 0

	if not isValidNumber(major) or
	   not isValidNumber(minor) or
	   not isValidNumber(patch) then return end

	return setmetatable({
		major = major,
		minor = minor,
		patch = patch,
		prerelease = prerelease,
		buildmeta = buildmeta
	}, mt)
end

setmetatable(GPM.Semver, { __call = function(_, ...) return mt.new(...) end })