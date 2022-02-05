# gpm [![Lint](https://github.com/Pika-Software/gpm/actions/workflows/lint.yml/badge.svg)](https://github.com/Pika-Software/gpm/actions/workflows/lint.yml)
GLua Package Manager

## Features
* Package information structure like [package.json](https://docs.npmjs.com/cli/v6/configuring-npm/package-json)
* [SemVer 2.0](https://semver.org/) support with [npm version matching](https://docs.npmjs.com/cli/v6/configuring-npm/package-json#dependencies)
* Package dependency support

## Planned features
 * [ ] Concommands support
 * [ ] Dependency downloading from github and url
 * [ ] Package registry with package verification
 * [ ] Package enviroment isolation
 * [ ] GUI Support (PUI?)
 * [ ] Package hot reload
 * [ ] Package auto update from github/url/registry

## How to create your own package?
1. Create `package.lua` and `main.lua` files in directory `lua/gpm/packages/<your-package-name>/`.
2. Enter information about your package in `package.lua` (See [package.lua](package.lua.md)), or just write `return {}`.
3. Write your code in `main.lua`, this is shared file, so you can write serverside and clientside code.

Also, you can run an existing addon via gpm, just add the code below to `package.lua`, and you don’t even need to add `main.lua`.
```lua
-- package.lua
return {
    -- gpm will run the specified file instead of main.lua
    main = "path/to/my/code/init.lua",
}
```

## License
[MIT](LICENSE) © Pika Software
