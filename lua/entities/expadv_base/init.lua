/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Base Class
   --- */

include( "shared.lua" )
include( "wiremod.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: [vNet] Receive Code
   --- */

local vNet = require( "vnet" ) -- Nope, You may not know what this is yet :D

function ENT:ReceivePackage( Package )
	local Received = Package:Table( )

	if Received.root then
		self.root = Received.root
		self.files = Received.files
	end

	if Received.cl_root then
		self.cl_root = Received.cl_root
		self.cl_files = Received.cl_files

		self:SendClientPackage( nil, self.cl_root, self.cl_files )
		
		hook.Add( "", self, function( self, Ply )
			self:SendClientPackage( Ply, self.cl_root, self.cl_files )
		end )
	end

end

function ENT:SendClientPackage( Player, Root, Files )
	-- Broadcast when player is nil!
	-- Also need to transmit the owner
end