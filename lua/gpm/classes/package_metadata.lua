
module( "GPM", package.seeall )

--- This class have one purpose, be used by Package
local package_metadata = CreateClass( "PackageMetadata" )

package_metadata.scheme = {
	name = Rule({
		required = true,
		match = "^[%l%d_-]+$",
	})
}

function package_metadata:__index( key )
	return Either( self.fields[key] ~= nil, self.fields[key], package_metadata[key] )
end

function package_metadata:pushError( field, reason )
	table.insert( self.errors, {
		field = field,
		reason = reason
	} )
end

function package_metadata:popError()
	return table.remove( self.errors, 1 )
end

function package_metadata:errorCount()
	return #self.errors
end

function package_metadata:hasErrors()
	return self:errorCount() ~= 0
end

function package_metadata:parseField( key, value )
	if key == nil then return end

	local rule = self.scheme[key]
	if not rule then return end

	local ok, err = rule:validate( value )

	if ok then
		self.fields[key] = value
	else
		self:pushError( key, err )
	end
end

function package_metadata:parseMetadata( metadata )
	if not istable( metadata ) then return end

	for key, value in pairs( metadata ) do
		self:parseField( key, value )
	end
end

function package_metadata.new( metadata )
	local metadata = InheritClass( package_metadata )

	metadata.errors = {}
	metadata.fields = {}

	metadata:parseMetadata( metadata )

	return metadata
end

PackageMetadata = setmetatable({}, { __call = function(_, ...) return package_metadata.new(...) end })
