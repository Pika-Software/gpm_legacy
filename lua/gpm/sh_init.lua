GPM = GPM or {}
local GPM = GPM

function GPM.CheckType(value, narg, tname, errorlevel)
	if type(value) == tname then return end

	local dinfo = debug.getinfo(2, 'n')
	local fname = dinfo and dinfo.name or 'func'
	local serror = ('bad argument #%d to \'%s\' (%s expected, got %s)'):format(narg, fname, tname, type(value))

	error(serror, errorlevel or 2)
end

function GPM.Path(filename, dir)
	if not isstring(filename) then return end
	if dir and not isstring(dir) then return end

	if dir and not string.EndsWith(dir, '/') then
		dir = dir .. '/'
	end

	if dir then
		return dir ..filename
	else
		return filename
	end
end

function GPM.SafeInclude(filename)
	GPM.CheckType(filename, 1, 'string', 3)

	local errorhandler = debug.getregistry()[1]
	local lasterr
	debug.getregistry()[1] = function(err)
		lasterr = err
		return errorhandler(err)
	end

	local args = { include(filename) }
	debug.getregistry()[1] = errorhandler

	return lasterr == nil, lasterr or unpack(args)
end

function GPM.CL(filename, dir)
	GPM.CheckType(filename, 1, 'string', 3)
	local path = GPM.Path(filename, dir)

	if SERVER then
		AddCSLuaFile(path)
	else
		return GPM.SafeInclude(path)
	end
end

function GPM.SV(filename, dir)
	if CLIENT then return end
	GPM.CheckType(filename, 1, 'string', 3)

	local path = GPM.Path(filename, dir)
	return GPM.SafeInclude(path)
end

function GPM.SH(filename, dir)
	GPM.CheckType(filename, 1, 'string', 3)
	local path = GPM.Path(filename, dir)

	AddCSLuaFile(path)
	return GPM.SafeInclude(path)
end

GPM.SH('sh_include.lua', 'gpm')

print('\n\n\n')
local pkg = GPM.Package({
	name = 'framework',
	version = '1-dev',
	description = 'simple framework',
	keywords = {'framework', 'simple'},
	homepage = 'https://pika-soft.ru',
	bugs = 'https://pika-soft.ru/issues',
	author = 'Retro <retro@pika-soft.ru> (https://pika-soft.ru)',
	contributors = {
		'Prikolmen <prikolmen@pika-soft.ru>',
		'Angel (https://pika-soft.ru)',
		'Klen list'
	},
	funding = {
		'https://pika-soft.ru/sponsor',
		{
			type = 'patreon',
			url = 'https://patreon.com/pika-soft'
		}
	},
	dependencies = {
		foo = '1.0.0 - 2.9999.9999',
		bar = '>=1.0.2 <2.1.2',
		baz = '>1.0.2 <=2.3.4',
		boo = '2.0.1',
		qux = '<1.0.0 || >=2.3.1 <2.4.5 || >=2.5.2 <3.0.0',
		til = '~1.2',
		elf = '~1.2.3',
		two = '2.x',
		thr = '3.3.x',
	}
})

pkg:Print()
