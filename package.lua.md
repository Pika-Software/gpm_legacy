## Package.lua
Example
```lua
-- lua/gpm/packages/example/package.lua
return {
    name = "example",
    description = "My first example of gpm package",
    version = "1.0.0",
    dependencies = {
        ["example-sub"] = "*",
        ["another-example-sub"] = "*",
        ["utility-library"] = "*",
    },
    author = "You",
    license = "MIT"
}
```

### name
If you plan to publish your package, the most important things in your package.json are the name and version fields as they will be required. The name and version together form an identifier that is assumed to be completely unique. Changes to the package should come along with changes to the version. If you don't plan to publish your package, the name and version fields are optional.

The name is what your thing is called.

### version
If you plan to publish your package, the most important things in your package.json are the name and version fields as they will be required. The name and version together form an identifier that is assumed to be completely unique. Changes to the package should come along with changes to the version. If you don't plan to publish your package, the name and version fields are optional.

### description
Put a description in it. It's a string.

### keywords
Put keywords in it. It's an array of strings

### homepage
The url to the project homepage.

Example:
```lua
homepage = "https://github.com/owner/project#readme"
```

### bugs
The url to your project's issue tracker and / or the email address to which issues should be reported. These are helpful for people who encounter issues with your package.

It should look like this:
```lua
{
    url = "https://github.com/owner/project/issues",
    email = "project@hostname.com"
}
```
You can specify either one or both values. If you want to provide only a url, you can specify the value for "bugs" as a simple string instead of an object.

### license
You should specify a license for your package so that people know how they are permitted to use it, and any restrictions you're placing on it.

If you're using a common license such as BSD-2-Clause or MIT, add a current SPDX license identifier for the license you're using, like this:
```lua
return {
    license = "MIT"
}
```
You can check [the full list of SPDX license IDs](https://spdx.org/licenses/). Ideally you should pick one that is [OSI](https://opensource.org/licenses/alphabetical) approved.

If your package is licensed under multiple common licenses, use an SPDX license expression syntax version 2.0 string, like this:
```lua
return {
    license = "(ISC OR GPL-3.0)"
}
```

If you are using a license that hasn't been assigned an SPDX identifier, or if you are using a custom license, use a string value like this one:
```lua
return {
    license = "SEE LICENSE IN <filename>"
}
```

### people fields: author, contributors
The "author" is one person. "contributors" is an array of people. A "person" is an object with a "name" field and optionally "url" and "email", like this:
```lua
{
    name = "Barney Rubble",
    email = "b@rubble.com",
    url = "http://barnyrubble.tumblr.com/",
}
```

Or you can shorten that all into a single string, and gpm will parse it for you:
```lua
"Barney Rubble <b@rubble.com> (http://barnyrubble.tumblr.com/)"
```

Both email and url are optional either way.

### funding
You can specify an object containing an URL that provides up-to-date information about ways to help fund development of your package, or a string URL, or an array of these:
```lua
funding = {
  type = "individual",
  url = "http://example.com/donate"
}
funding = {
  type = "patreon",
  url = "https://www.patreon.com/my-account"
}
funding = "http://example.com/donate"
funding = {
  {
    type = "individual",
    url = "http://example.com/donate"
  },
  "http://example.com/donateAlso",
  {
    type = "patreon",
    url = "https://www.patreon.com/my-account"
  }
}
```

### main
The main field is a module ID that is the primary entry point to your program.

### repository
Specify the place where your code lives. This is helpful for people who want to contribute.

Do it like this:
```lua
repository = {
  type = "git",
  url = "https://github.com/Pika-Software/gpm.git"
}
repository = {
  type = "svn",
  url = "https://v8.googlecode.com/svn/trunk/"
}
```

### dependencies
Dependencies are specified in a simple object that maps a package name to a version range. The version range is a string which has one or more space-separated descriptors. Dependencies can also be identified with a tarball or git URL.

See [semver](https://docs.npmjs.com/cli/v6/using-npm/semver) for more details about specifying version ranges.
 * `version` Must match version exactly
 * `>version` Must be greater than version
 * `>=version` etc
 * `<version`
 * `<=version`
 * `~version` "Approximately equivalent to version" See [semver](https://docs.npmjs.com/cli/v6/using-npm/semver)
 * `^version` "Compatible with version" See [semver](https://docs.npmjs.com/cli/v6/using-npm/semver)
 * `1.2.x` 1.2.0, 1.2.1, etc., but not 1.3.0
 * `*` Matches any version
 * `""` (just an empty string) Same as `*`
 * `version1 - version2` Same as `>=version1 <=version2`.
 * `range1 || range2` Passes if either range1 or range2 are satisfied.

For example, these are all valid:
```lua
{
    dependencies = {
        ["foo"] = "1.0.0 - 2.9999.9999",
        ["bar"] = ">=1.0.2 <2.1.2",
        ["baz"] = ">1.0.2 <=2.3.4",
        ["boo"] = "2.0.1",
        ["qux"] = "<1.0.0 || >=2.3.1 <2.4.5 || >=2.5.2 <3.0.0",
        ["til"] = "~1.2",
        ["elf"] = "~1.2.3",
        ["two"] = "2.x",
        ["thr"] = "3.3.x"
    }
}
```

### peerDependencies
In some cases, you want to express the compatibility of your package with a host tool or library, while not necessarily doing a include of this host. This is usually referred to as a _plugin_. Notably, your module may be exposing a specific interface, expected and specified by the host documentation.

For example:
```lua
return {
    name = "tea-latte",
    version = "1.3.5",
    peerDependencies = {
        ["tea"] = "2.x"
    }
}
```
This ensures your package `tea-latte` can be installed along with the second major version of the host package `tea` only.
```
├── tea-latte@1.3.5
└── tea@2.2.0
```

### optionalDependencies
If a dependency can be used, but you would like gpm to proceed if it cannot be found or fails, then you may put it in the optionalDependencies object. This is a map of package name to version, just like the dependencies object. The difference is that failures do not cause resolving to fail.

It is still your program's responsibility to handle the lack of the dependency. For example, something like this:
```lua
local foo

local foo_package = GPM.Loader.FindPackage("foo")
if foo_package and foo_package.state == "loaded" and goodFooVersion(foo_package.version) then
    foo = FooGlobal
end

-- ... later ...

if foo then
    foo.doFooThings()
end
```
