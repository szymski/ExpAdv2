/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Shared Info!
   --- */
AddCSLuaFile( )

ENT.Type 			= "anim"
ENT.Base 			= "expadv_gate"
ENT.ExpAdv 			= true
ENT.Screen 			= true

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Resolution
   --- */

if SERVER then
	util.AddNetworkString("expadv.resolution")
	
	function ENT:SetResolution(res)
		self.RESOLUTION = res or 512

		timer.Simple(1, function()
			if IsValid(self) then
				net.Start("expadv.resolution")
					net.WriteEntity(self)
					net.WriteUInt(self.RESOLUTION, 32)
				net.Broadcast()
			end
		end)
	end

	function ENT:GetResolution(res)
		return self.RESOLUTION or res or 512
	end

	hook.Add( "Expadv.SyncCodeToNewPlayer", "expadv.resolution", function(gate, player)
		if gate.Screen and gate.RESOLUTION then
			net.Start("expadv.resolution")
				net.WriteEntity(gate)
				net.WriteUInt(gate.RESOLUTION, 32)
			net.Broadcast()
		end
	end)


	hook.Add( "Expadv.BuildDupeInfo", "expadv.pod", function( gate, DupeTable )
		if gate.Screen then
			DupeTable.Scren_Resolution = gate.RESOLUTION
		end
	end )

	hook.Add( "Expadv.PasteDupeInfo", "expadv.pod", function( gate, DupeTable, FromID )
		if gate.Screen and DupeTable.Scren_Resolution then
			gate:SetResolution(DupeTable.Scren_Resolution)
		end
	end )


elseif CLIENT then
	net.Receive("expadv.resolution", function()
		local scr = net.ReadEntity()

		if IsValid(scr) and scr.ExpAdv and scr.Screen then
			scr.RT_Data = EXPADV.GetRenderTarget(net.ReadUInt(32))
		end
	end)
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: GetCursor
   --- */

require( "vector2" )

function ENT:GetCursor( Player )

	local Monitor = EXPADV.GetMonitor(self)
	if !Monitor or !IsValid( Player ) then return nil end

	local scrSize, res = self:GetResolution(512), Monitor.RS

	if scrSize == 256 then
		res = res * 2
	elseif scrSize == 1024 then
		res = res * 0.5
	end

	if Player:EyePos():Distance( self:GetPos() ) > 156 then return end

	local Start, Dir = Player:GetShootPos( ), Player:GetAimVector( )
	
	local Ang = self:LocalToWorldAngles( Monitor.rot )
	local Pos = self:LocalToWorld( Monitor.offset )
	
	local A = Ang:Up( ):Dot( Dir )
	if (A == 0 or A > 0) then return nil end

	local B = Ang:Up( ):Dot( Pos - Start ) / A

	

	local HitPos = WorldToLocal( Start + Dir * B, Angle( ), Pos, Ang )
	local X = (0.5 + HitPos.x / (res * scrSize / Monitor.RatioX)) * scrSize
	local Y = (0.5 - HitPos.y / (res * scrSize)) * scrSize
			
	if (X < 0 or X > scrSize or Y < 0 or Y > scrSize) then return nil end

	return Vector2( X, Y )
end

function ENT:ScreenToLocalVector( Vec2 )
	local Monitor = EXPADV.GetMonitor(self)
	if !Monitor then return Vector( 0, 0, 0) end

	local scrSize, res = self:GetResolution(512), Monitor.RS

	if scrSize == 256 then
		res = res * 2
	elseif scrSize == 1024 then
		res = res * 0.5
	end

	Vec2 = (Vec2 - Vector2(scrSize * 0.5, scrSize * 0.5)) * Vector2( Monitor.RS / Monitor.RatioX, res )

	local Vec = Vector( Vec2.x, -Vec2.y, 0 )

	Vec:Rotate( Monitor.rot )

	return Vec + Monitor.offset
end

function ENT:ScreenToWorld( Vec2 )
	return self:LocalToWorld( self:ScreenToLocalVector( Vec2 ) )
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: FPS / BG
   --- */

function ENT:SetFPS( Value )
	self.__fps = math.Clamp( math.ceil( Value ), 1, 60 )
end

function ENT:GetFPS( )
	return self.__fps or 24
end

function ENT:SetBackGround(Color)
	self.__bg = Color
end

function ENT:GetBackGround( )
	return self.__bg or Color(50, 50, 50, 255)
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: We need a render target and material
   --- */

EXPADV.RenderTargets = EXPADV.RenderTargets or {[256] = {}, [512] = {}, [1024] = {}}
local MaterialInfo = { ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$ignorez"] = 1, ["$nolod"] = 1, }

function EXPADV.GetRenderTarget(Res)
	Res = Res or 512

	local rtTable = EXPADV.RenderTargets[Res]
	if !rtTable then return end
	
	for id, data in pairs(rtTable) do

		if data.CACHED then --and data.RES == Res then
			data.CACHED = false
			data.CLEAR = true
			return data
		end
	end

	local ID = #rtTable + 1

	if ID <= 32 then
		local Data = {
			ID = ID,
			RES = Res,
			CLEAR = true,
			CACHED = false,
			RT = GetRenderTarget( "expadv_rt_" .. Res .. "_" .. ID, Res, Res ),
			MAT = CreateMaterial( "expadv_rt_" .. Res .. "_" .. ID, "UnlitGeneric", MaterialInfo ),
		}

		rtTable[ID] = Data

		return Data
	end

	return nil
end

function EXPADV.CacheRenderTarget(RT)
	if RT then
		local rtTable = EXPADV.RenderTargets[RT.RES]
		if !rtTable then return end
		
		local Data = rtTable[RT.ID]
		if Data then Data.CACHED = true end
	end
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Render Montior
   --- */

AccessorFunc( ENT, "_pauseRender", "RenderingPaused", FORCE_BOOL )
AccessorFunc( ENT, "_noClear", "NoClearFrame", FORCE_BOOL )

function ENT:GetResolution() return self.RT_Data and self.RT_Data.RES or 512 end
function ENT:PreDrawScreen(scrAspect, scrSize) return false end
function ENT:PostDrawScreen(scrAspect, scrSize) return false end

function ENT:Draw()
	local time = SysTime()
	local context = self.Context

	if !self.RT_Data then return self:DrawModel() end

	if !context or !context.Online then
		if !self.IsErrorScreen then
			--self:CreateErrorScreen(context)
			self.IsErrorScreen = true
		end
	elseif !self:GetRenderingPaused() and (!self.NextRender or self.NextRender <= time) then
		self:DoScreenUpdate(context)
		self.IsErrorScreen = false
		self.NextRender = time + (1 / self:GetFPS())
	end

	self:DrawModel( )

	local monitor = EXPADV.GetMonitor(self)
	
	if monitor then
			local rtData = self.RT_Data
			local scrSize = self:GetResolution()
			local pos, ang, res, ratio = self:LocalToWorld(monitor.min), self:LocalToWorldAngles(monitor.rot), monitor.RS, monitor.RatioX

			if scrSize == 256 then
				res = res * 2
			elseif scrSize == 1024 then
				res = res * 0.5
			end
			
			local aspect = 1 / ratio
			
			local scrAspect = scrSize * aspect

			cam.Start3D2D(pos, ang, res)
				surface.SetDrawColor(self:GetBackGround())
				surface.DrawRect(0, 0, scrAspect, scrAspect)

				if !self:PreDrawScreen(scrAspect, scrSize) and rtData then
					-- If our predrawscreen returns false, we render the screen.

					local prev = rtData.MAT:GetTexture("$basetexture")
								 rtData.MAT:SetTexture("$basetexture", rtData.RT)

					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(rtData.MAT)
					surface.DrawTexturedRect(0, 0, scrAspect, scrAspect) //UV(0, 0, scrAspect, scrAspect, 0, 0, endUV, endUV)

					rtData.MAT:SetTexture("$basetexture", prev)
				end

				self:PostDrawScreen(scrAspect, scrSize)

			cam.End3D2D( )
	end
end

function ENT:DoScreenUpdate(context)
	local rtData = self.RT_Data
	local scrSize = self:GetResolution(512)
	local event = context.event_drawScreen

	if event and rtData then
		render.PushRenderTarget(rtData.RT)
		render.OverrideAlphaWriteEnable(true, true)

		if rtData.CLEAR or !self:GetNoClearFrame() then
			render.ClearDepth()
			render.Clear(0, 0, 0, 0)
			rtData.CLEAR = false
		end

		cam.Start2D( )

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetTextColor(0, 0, 0, 255)
			
			context.In2DRender = true
			context.Matrices = 0

			context:Execute("Event drawScreen", event, scrSize, scrSize)

			if context.Matrices > 0 then
				for i=1, context.Matrices do cam.PopModelMatrix() end
			end
			
			context.In2DRender = false

		cam.End2D( )

		render.OverrideAlphaWriteEnable(false)
		render.PopRenderTarget()
	end
end

function ENT:OnRemove()
	EXPADV.CacheRenderTarget(self.RT_Data)
	
	hook.Remove( "PlayerInitialSpawn", self )

	if !self:IsRunning( ) then return end
	
	self.Context:ShutDown( )
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Overlay
   --- */

function ENT:GetOverlayPos( )
	return self:ScreenToWorld( Vector2( 512, 256 ) )
end

