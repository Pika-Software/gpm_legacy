-- Package class

local GPM = GPM
GPM.Package = GPM.Package or {}

assert(GPM.Semver, 'Semver module must be loaded')

local function isArray(arr)
    return #arr > 0
end

local function parseFunding(v)
    assert(isstring(v) or istable(v), 'invalid funding information type (expected string or table)')

    if isstring(v) then
        return { url = v }
    end

    assert(v.url, 'url not found in funding information')

    return {
        url = v.url,
        type = v.type
    }
end

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
    assert(t.version == nil or isstring(t.version), ('invalid %q package version (expected string)'):format(pkg.name))
    if t.version then
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

    -- Parsing author
    if t.author then
        local success, res = pcall(GPM.Author, t.author)
        assert(success, ('failed to parse %s: invalid author. See error below:\n%s'):format(pkg, res))

        pkg.author = res
    end

    -- Parsing contributors
    assert(t.contributors == nil or istable(t.contributors), ('failed to parse %s: invalid contributors'):format(pkg))
    if t.contributors then
        pkg.contributors = {}

        for i, v in ipairs(t.contributors) do
            local success, res = pcall(GPM.Author, v)
            assert(success, ('failed to parse %s: invalid contributor at index %d. See error below:\n%s'):format(pkg, i, res))

            pkg.contributors[i] = res
        end
    end

    -- Parsing funding
    assert(t.funding == nil or isstring(t.funding) or istable(t.funding), ('failed to parse %s: invalid funding'):format(pkg))
    if t.funding then
        if istable(t.funding) and isArray(t.funding) then
            pkg.funding = {}

            for i, v in ipairs(t.funding) do
                local success, res = pcall(parseFunding, v)
                assert(success, ('failed to parse %s: invalid funding at index %d. See error below:\n%s'):format(pkg, i, res))
    
                pkg.funding[i] = res
            end
        else
            local success, res = pcall(parseFunding, t.funding)
            assert(success, ('failed to parse %s: invalid funding. See error below:\n%s'):format(pkg, res))

            pkg.funding = res
        end
    end

    return pkg
end

setmetatable(GPM.Package, { __call = function(_, ...) return mt.new(...) end })
