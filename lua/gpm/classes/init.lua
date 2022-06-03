
module( "GPM", package.seeall )

Classes = Classes or {}
Classes.Base = Classes.Base or {}

local base_class = Classes.Base
base_class.__index = base_class

base_class.Name = "Base Class"

function base_class:__tostring()
	return ("%s %p"):format(self.Name, self)
end

function base_class.new()
	NotImplementedError()
end

-- seriously i don't know why i'm doing this, lol
-- and sorry for this mess
-- just wanted functions for creating classes and getting them without repeating code

function GetClass( name )
	return Classes[name]
end

function InheritClass( base )
	if isstring( base ) then
		base = GetClass( base )
	end

	if not istable(base) then
		error("Invalid base class")
	end

	local out = setmetatable( {}, base )
	return out
end

function CreateClass( name, base )
	local class = GetClass( name ) or InheritClass( base or base_class )

	-- Checks, if class have __index property. If not, set to itself
	if not rawget(class, "__index") then
		class.__index = class
	end

	Classes[name] = class
	class.Name = name

	return class
end
