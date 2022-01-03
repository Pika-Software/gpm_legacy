-- Semver lua parser. Based on https://github.com/kikito/semver.lua

local GPM = GPM
GPM.Semver = GPM.Semver or {}

local function isValidNumber(num, name) -- number must be a positive and integer
	assert(num >= 0, name .. 'must be a valid positive number')
	assert(math.floor(num) == num, name .. 'must be a integer')
end

-- splitByDot('a.bbc.d') == {'a', 'bbc', 'd'}
local function splitByDot(str)
	local t, count = {}, 0
	str = str or ''

	str:gsub('([^%.]+)', function(c)
		count = count + 1
		t[count] = c
	end)

	return t
end

local function parsePreleaseAndBuildmeta(prerelease_and_buildmeta)
	if not prerelease_and_buildmeta or prerelease_and_buildmeta == '' then return end

	local prerelease, buildmeta = prerelease_and_buildmeta:match('^(-[^+]+)(+.+)$')
	if not (prerelease and buildmeta) then
		prerelease = prerelease_and_buildmeta:match('^(-.+)$')
		buildmeta = prerelease_and_buildmeta:match('^(+.+)$')
	end

	assert(prerelease or buildmeta, ('the parameter %q must begin with + or - to denote a prerelease or a build'):format(prerelease_and_buildmeta))

	if prerelease then
		prerelease = prerelease:match('^-(%w[%.%w-]*)$')
		assert(prerelease, ('the prerelease %q is not valid'):format(prerelease))
	end

	if buildmeta then
		buildmeta = buildmeta:match('^%+(%w[%.%w-]*)$')
		assert(buildmeta, ('the build %q is not valid'):format(buildmeta))
	end

	return prerelease, buildmeta
end

local function parseVersion(ver)
	local major, minor, patch, prerelease_and_buildmeta = string.match(ver, '^(%d+)%.?(%d*)%.?(%d*)(.-)$')
	assert(type(major) == 'string', ('can not parse version from %q'):format(ver))

	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
	local prelease, buildmeta = parsePreleaseAndBuildmeta(prerelease_and_buildmeta)
	return major, minor, patch, prelease, buildmeta
end


-- return 0 if a == b, -1 if a < b, and 1 if a > b
local function compare(a, b)
	return a == b and 0 or a < b and -1 or 1
end

local function compareIds(id, otherId)
	if id == otherId then return 0
	elseif not id then return -1
	elseif not otherId then return 1 end

	local num, otherNum = tonumber(id), tonumber(otherId)

	if num and otherNum then -- numerical comparison
		return compare(num, otherNum)
	elseif num then -- numericals are always smaller than alphanums
		return -1
	elseif otherNum then
		return 1
	else
		return compare(id, otherId) -- alphanumerical comparison
	end
end

local function smallerIdList(ids, otherIds)
	local len = #ids
	local comp

	for i = 1, len do
		comp = compareIds(ids[i], otherIds[i])

		if comp ~= 0 then
			return comp == -1
		end
		-- if comp == 0, continue loop
	end

	return myLength < #otherIds
end

local function smallerPrerelease(first, seconds)
	if first == seconds or not first then return false
	elseif not seconds then return true end

	return smallerIdList(splitByDot(first), splitByDot(seconds))
end

local mt = {}
mt.__index = mt

function mt:nextMajor()
	return self.new(self.major + 1, 0, 0)
end
function mt:nextMinor()
	return self.new(self.major, self.minor + 1, 0)
end
function mt:nextPatch()
	return self.new(self.major, self.minor, self.patch + 1)
end

function mt:__eq(other)
	return istable(other) and
		self.major == other.major and
		self.minor == other.minor and
		self.patch == other.patch and
		self.prerelease == other.prerelease
		-- notice that build is ignored for precedence in semver 2.0.0
end

function mt:__lt(other)
	if self.major ~= other.major then return self.major < other.major end
	if self.minor ~= other.minor then return self.minor < other.minor end
	if self.patch ~= other.patch then return self.patch < other.patch end
	return smallerPrerelease(self.prerelease, other.prerelease)
	-- notice that build is ignored for precedence in semver 2.0.0
end

-- This works like the 'pessimisstic operator' in Rubygems.
-- if a and b are versions, a ^ b means 'b is backwards-compatible with a'
-- in other words, 'it's safe to upgrade from a to b'
function mt:__pow(other)
	if self.major == 0 then
		return self == other
	end

	return self.major == other.major and
		self.minor <= other.minor
end

-- This works like 'satisfies' (fuzzy matching) in npm.
-- https://docs.npmjs.com/cli/v6/using-npm/semver
-- A version range is a set of comparators which specify versions that satisfy the range.
-- A comparator is composed of an operator and a version. The set of primitive operators is:
--   < Less than
--   <= Less than or equal to
--   > Greater than
--   >= Greater than or equal to
--   = Equal. If no operator is specified, then equality is assumed, so this operator
--     is optional, but MAY be included.
-- Comparators can be joined by whitespace to form a comparator set, which is satisfied by
-- the intersection of all of the comparators it includes.
-- A range is composed of one or more comparator sets, joined by ||. A version matches
-- a range if and only if every comparator in at least one of the ||-separated comparator
-- sets is satisfied by the version.
-- A 'version' is described by the v2.0.0 specification found at https://semver.org/.
-- A leading '=' or 'v' character is stripped off and ignored
function mt:__mod(str)
	-- version range := comparator sets
	if str:find('||', nil, true) then
		local start, pos, part = 1
		while true do
			pos = str:find('||', start, true)
			part = str:sub(start, pos and (pos - 1))

			if self % part then return true end
			if not pos then return false end
			start = pos + 2
	  	end
	end

	-- comparator set := comparators
	str = str:gsub('%s+', ' ')
			:gsub('^%s+', '')
			:gsub('%s+$', '')

	if str:find(' ', nil, true) then
		local start, pos, part = 1
		while true do
			pos = str:find(' ', start, true)
			part = str:sub(start, pos and (pos - 1))

			-- Hyphen Ranges: X.Y.Z - A.B.C
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#hyphen-ranges-xyz---abc
			if pos and str:sub(pos, pos + 2) == ' - ' then
				if not (self % ('>=' .. part)) then return false end

				start = pos + 3
				pos = str:find(' ', start, true)
				part = str:sub(start, pos and (pos - 1))

				if not (self % ('<=' .. part)) then return false end
			else
				if not (self % part) then return false end
			end

			if not pos then return true end
			start = pos + 1
		end

		return true
	end

	-- comparators := operator + version
	str = str:gsub('^=', '')
			:gsub('^v', '')

	-- X-Ranges *
	-- Any of X, x, or * may be used to 'stand in' for one of the numeric values in the [major, minor, patch] tuple.
	-- https://docs.npmjs.com/cli/v6/using-npm/semver#x-ranges-12x-1x-12-
	if str == '' or str == '*' then return self % '>=0.0.0' end

	local pos = str:find('%d')
	assert(pos, 'Version range must starts with number: ' .. str)

	-- X-Ranges 1.2.x 1.X 1.2.*
	-- Any of X, x, or * may be used to 'stand in' for one of the numeric values in the [major, minor, patch] tuple.
	-- https://docs.npmjs.com/cli/v6/using-npm/semver#x-ranges-12x-1x-12-
	local operator = pos == 1 and '=' or str:sub(1, pos - 1)
	local version = str:sub(pos):gsub('%.[xX*]', '')
	local xrange = math.max(0, 2 - select(2, version:gsub('%.', '')))
	for _ = 1, xrange do
		version = version .. '.0'
	end

	local sv = self.new(version)
	if operator == '<' then
	  	return self < sv
	end
	-- primitive operators
	-- https://docs.npmjs.com/cli/v6/using-npm/semver#ranges
	if operator == '<=' then
		if xrange > 0 then
			if xrange == 1 then
				sv = sv:nextMinor()
			elseif xrange == 2 then
				sv = sv:nextMajor()
			end

			return self < sv
		end

		return self <= sv
	end

	if operator == '>' then
		if xrange > 0 then
			if xrange == 1 then
				sv = sv:nextMinor()
			elseif xrange == 2 then
				sv = sv:nextMajor()
			end

			return self >= sv
		end

		return self > sv
	end

	if operator == '>=' then
	  	return self >= sv
	end

	if operator == '=' then
		if xrange > 0 then
			if self < sv then
				return false
			end

			if xrange == 1 then
				sv = sv:nextMinor()
			elseif xrange == 2 then
				sv = sv:nextMajor()
			end

			return self < sv
		end

		return self == sv
	end

	-- Caret Ranges ^1.2.3 ^0.2.5 ^0.0.4
	-- Allows changes that do not modify the left-most non-zero digit in the [major, minor, patch] tuple.
	-- In other words, this allows patch and minor updates for versions 1.0.0 and above, patch updates for
	-- versions 0.X >=0.1.0, and no updates for versions 0.0.X.
	-- https://docs.npmjs.com/cli/v6/using-npm/semver#caret-ranges-123-025-004
	if operator == '^' then
		if sv.major == 0 and xrange < 2 then
			if sv.minor == 0 and xrange < 1 then
				return self.major == 0 and self.minor == 0 and self >= sv and self < sv:nextPatch()
			end

			return self.major == 0 and self >= sv and self < sv:nextMinor()
		end

		return self.major == sv.major and self >= sv and self < sv:nextMajor()
	end

	-- Tilde Ranges ~1.2.3 ~1.2 ~1
	-- Allows patch-level changes if a minor version is specified on the comparator. Allows minor-level changes if not.
	-- https://docs.npmjs.com/cli/v6/using-npm/semver#tilde-ranges-123-12-1
	if operator == '~' then
		if self < sv then
			return false
		end

		if xrange == 2 then
			return self < sv:nextMajor()
		end

		return self < sv:nextMinor()
	end

	assert(false, 'Invaild operator found: ' .. operator)
end

function mt:__tostring()
	local buffer = { ('%d.%d.%d'):format(self.major, self.minor, self.patch) }
	if self.prerelease then table.insert(buffer, '-' .. self.prerelease) end
	if self.buildmeta then table.insert(buffer, '+' .. self.buildmeta) end
	return table.concat(buffer)
end

function mt.new(major, minor, patch, prerelease, buildmeta)
	assert(major, 'at least one parameter is needed')

	if type(major) == 'string' then
		major, minor, patch, prerelease, buildmeta = parseVersion(major)
	end
	minor = minor or 0
	patch = patch or 0

	isValidNumber(major, 'major')
	isValidNumber(minor, 'minor')
	isValidNumber(patch, 'patch')

	return setmetatable({
		major = major,
		minor = minor,
		patch = patch,
		prerelease = prerelease,
		buildmeta = buildmeta
	}, mt)
end

setmetatable(GPM.Semver, { __call = function(_, ...) return mt.new(...) end })
