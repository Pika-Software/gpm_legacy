-- Package class

local GPM = GPM
GPM.Package = GPM.Package or {}

assert(GPM.Semver, 'Semver module must be loaded')

local mt = {}
mt.__index = mt

function mt:__tostring()
    return tostring(self.name) .. '@' .. tostring(self.version)
end

function mt:Print()
    print(self)
    print('==========================================')
    PrintTable(self)
end

function mt.new(t)
    assert(istable(t), 'package information must be a table')

    local pkg = setmetatable({}, mt)
    
    -- Parsing name
    assert(not t.name or isstring(t.name), 'invalid package name') -- TODO: add pattern matching to validate name
    pkg.name = t.name or 'unknown_package'

    -- Parsing version
    if t.version then
        assert(t.version, ('invalid %q package version (expected string)'):format(pkg.name))

        local success, res = pcall(GPM.Semver, t.version)
        assert(success, ('failed to parse version of %q package:\n%s'):format(pkg.name, res))

        pkg.version = res
    else
        pkg.version = GPM.Semver('0')
    end

    -- Parsing description
    assert(t.description == nil or isstring(t.description), ('failed to parse %s: invalid description'):format(pkg))
    pkg.description = t.description

    -- Parsing keywords
    assert(t.keywords == nil or istable(t.keywords), ('failed to parse %s: invalid keywords'):format(pkg))
    if t.keywords then
        pkg.keywords = {}

        for i, v in ipairs(t.keywords) do
            assert(isstring(v), ('failed to parse %s: invalid keyword %q at index %d (expected string, got %s)'):format(pkg, tostring(v), i, type(v)))
            pkg.keywords[i] = v
        end
    end

    -- Parsing homepage
    assert(t.homepage == nil or isstring(t.homepage), ('failed to parse %s: invalid homepage'):format(pkg)) -- validate url?
    pkg.homepage = t.homepage

    -- Parsing bugs
    assert(t.bugs == nil or isstring(t.bugs) or istable(t.bugs), ('failed to parse %s: invalid bugs'):format(pkg)) -- validate url?
    pkg.bugs = t.bugs
    if istable(t.bugs) then
        assert(t.bugs.url or t.bugs.email, ('failed to parse %s: no url or email in bugs'):format(pkg))
        assert(t.bugs.url == nil or isstring(t.bugs.url), ('failed to parse %s: bugs url must be a string'):format(pkg))
        assert(t.bugs.email == nil or isstring(t.bugs.email), ('failed to parse %s: bugs email must be a string'):format(pkg))

        pkg.bugs = {
            url = t.bugs.url,
            email = t.bugs.email
        }
    end

    -- Parsing license
    assert(t.license == nil or isstring(t.license), ('failed to parse %s: invalid bugs'):format(pkg))
    if isstring(t.license) then -- TODO: add spdx expressions support. https://docs.npmjs.com/cli/v8/configuring-npm/package-json#license
        pkg.license = t.license
    end

    return pkg
end

setmetatable(GPM.Package, { __call = function(_, ...) return mt.new(...) end })
