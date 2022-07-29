
module( "GPM", package.seeall )

local base = CreateClass("BaseLoader")

--- Returns if package is valid or not
-- @param id of a package
-- @return true if valid, otherwise false
function base.isValid(id)
	NotImplementedError()
end

--- Returns if package ready to load
-- Mostly used to indicated, if package downloaded or not
-- @param id of a package
-- @return true if ready, otherwise false
function base.isReady(id)
	NotImplementedError()
end

--- Loads metadata from package
-- @param id of a package
-- @return a package metadata in table.
function base.loadMetadata( nam )
	NotImplementedError()
end


function GetLoader( name )
	return GetClass( name )
end

function CreateLoader( name )
	return CreateClass( name, base )
end
