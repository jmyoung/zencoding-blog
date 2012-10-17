-- View scripts
-- Copyright (C) 2004, Eagle Dynamics.
-- Don't change existing values, they are requested from Ñ++!
-- Use these indices in Snap and CockpitLocalPoint tables.
dofile("Scripts/Database/wsTypes.lua")
--dofile("./Config/viewConsumer.lua")

PlaneIndexByType = -- indices in snap views table
{
	[Su_27]   = 1,
	[Su_33]   = 2,
	[Su_25]   = 3,
	[Su_25T]  = 4,
	[Su_39]   = 4,
	[MiG_29]  = 5,
	[MiG_29G] = 5,
	[MiG_29C] = 5,
	[MIG_29K] = 6,
	[A_10A]   = 7,	
	[F_15]    = 8,
	[KA_50]   = 9,
	[A_10C]   = 11,
	[P_51D]   = 12,
}

function validate(tbl,itype)
	local default = Su_27
	if itype > 150 then --LastPlaneType
	   default = KA_50
	end
    return tbl[itype] or tbl[default]
end

function fulcrum_copy(tbl)
	tbl[MiG_29G]  = tbl[MiG_29]; 
	tbl[MiG_29C]  = tbl[MiG_29]; 
end

CockpitMouse = true --false
CockpitMouseSpeedSlow = 1.0
CockpitMouseSpeedNormal = 10.0
CockpitMouseSpeedFast = 20.0
CockpitKeyboardAccelerationSlow = 5.0
CockpitKeyboardAccelerationNormal = 30.0
CockpitKeyboardAccelerationFast = 80.0
CockpitKeyboardZoomAcceleration = 300.0
DisableSnapViewsSaving = false
UseDefaultSnapViews = true
CockpitPanStepHor = 45.0
CockpitPanStepVert = 30.0
CockpitNyMove = true

CockpitHAngleAccelerateTimeMax = 0.15
CockpitVAngleAccelerateTimeMax = 0.15
CockpitZoomAccelerateTimeMax   = 0.2

function checkSnapviewTable(iPlane,iKey)
	local index = validate(PlaneIndexByType,iPlane)
	local snaps = DefaultSnapView.Snap
	if not UseDefaultSnapViews and Snap then
		  snaps = Snap
	end
	if snaps[index] == nil then
	    for i = 1,13 do
			snaps[index][i] = 
			{
			   hAngle    =  0, 
			   vAngle    = -10,
			   viewAngle =  135,
			   x_trans   =  0,
			   y_trans   =  0,
			   z_trans   =  0,
			   rollAngle =  0,
			}
		end
	end
	return snaps[index][iKey]
end

function GetSnapView(iPlane, iKey)
	local  s = checkSnapviewTable(iPlane, iKey)
	return s.hAngle, 
		   s.vAngle,
		   s.viewAngle,
		   s.x_trans,
		   s.y_trans,
		   s.z_trans,
		   s.rollAngle
end

function SetSnapView(iPlane, iKey, hAngle, vAngle, viewAngle,x_trans,y_trans,z_trans,rollAngle)
	local  s = checkSnapviewTable(iPlane, iKey)
		   s.hAngle      = hAngle	
		   s.vAngle      = vAngle	
		   s.viewAngle   = viewAngle	
		   s.x_trans     = x_trans
		   s.y_trans     = y_trans
		   s.z_trans     = z_trans
		   s.rollAngle   = rollAngle
end

function WriteSnapViews(fileName)
	local lfs		= require("lfs")
	local path      = lfs.writedir().."Config/View"
	local attr 		= lfs.attributes(path);
	if not attr then
		lfs.mkdir(path)
	elseif attr.mode ~= 'directory' then
		return
	end
	local file = io.open(path.."/SnapViews.lua","w")
	if file then
		local t  = {}
		local snaps = DefaultSnapView.Snap
		if not UseDefaultSnapViews and Snap then
			snaps = Snap
		end
		Serialize(file,"Snap",snaps,t)
		file:close()
	end
end
-- Camera view angle limits {view angle min, view angle max}.

CameraViewAngleLimits = {}
CameraViewAngleLimits[Su_27]   = {20.0, 120.0} 
CameraViewAngleLimits[Su_33]   = {20.0, 120.0}
CameraViewAngleLimits[Su_25]   = {20.0, 120.0}
CameraViewAngleLimits[Su_25T]  = {55.76, 158.21}  -- Default 20.0, 120.0
CameraViewAngleLimits[MiG_29]  = {20.0, 120.0}
CameraViewAngleLimits[MIG_29K] = {20.0, 120.0}
CameraViewAngleLimits[F_15]    = {20.0, 140.0}
CameraViewAngleLimits[A_10A]   = {55.76, 135.0}	-- Default 20.0,140.0
CameraViewAngleLimits[KA_50]   = {55.76, 135.0}  -- Default 20.0,140.0
CameraViewAngleLimits[A_10C]   = CameraViewAngleLimits[A_10A]
CameraViewAngleLimits[P_51D]   = {20.0, 120.0}

fulcrum_copy(CameraViewAngleLimits)

function GetCameraViewAngleLimits(iType)
	local p = validate(CameraViewAngleLimits,iType)
	return p[1], p[2]
end

function SetCameraViewAngleLimits(iType, viewAngMin, viewAngMax)
	local p = validate(CameraViewAngleLimits,iType)
	p[1] = viewAngMin
	p[2] = viewAngMax
end

CameraAngleRestriction = {}
CameraAngleRestriction[Su_27]   =  {1,60,0.4}
CameraAngleRestriction[Su_33]   =  {1,60,0.4}
CameraAngleRestriction[Su_25]   =  {1,60,0.4}
CameraAngleRestriction[Su_25T]  =  {1,60,0.4}
CameraAngleRestriction[MiG_29]  =  {1,60,0.4}
CameraAngleRestriction[MIG_29K] =  {1,60,0.4}
CameraAngleRestriction[F_15]    =  {1,60,0.4}
CameraAngleRestriction[A_10A]   =  {1,90,0.5}
CameraAngleRestriction[KA_50]   =  {0,60,0.4}
CameraAngleRestriction[A_10C]   =  {0,90,0.5}
CameraAngleRestriction[P_51D]   =  {0,90,0.5}

fulcrum_copy(CameraAngleRestriction)

function GetCameraAngleRestriction(iType)
	local p = validate(CameraAngleRestriction,iType)
	return  p[1], p[2], p[3]
end 


-- HUD displacement for the HUD-only view (for cockpit builders).
-- Y-axis - up/down, Z-axis - left/right, in meters. X-axis (size) not implemented yet. 
HUDOnlyPoint = {}
HUDOnlyPoint[Su_27] = {0.0, 0.0, 0.0}
function GetHUDOnlyPoint(iType)
	local  p = validate(HUDOnlyPoint,iType)
	return p[1], p[2], p[3]
end

-- HUD RGB color 
HUDColor = {}
HUDColor[Su_27] = {0, 255, 0}
function GetHUDColor(iType)
	local p = validate(HUDColor,iType)
	return p[1], p[2], p[3]
end

function NaturalHeadMoving(tang, roll, omz)
	local r = roll
	if r > 90.0 then
		r = 180.0 - r
	elseif roll < -90.0 then
		r = -180.0 - r
	end
	local hAngle = -0.25 * r
	local vAngle = math.min(math.max(0.0, 0.4 * tang + 45.0 * omz), 90.0)
	return hAngle, vAngle
end

ExternalMouse = true
ExternalMouseSpeedSlow = 1.0
ExternalMouseSpeedNormal = 5.0
ExternalMouseSpeedFast = 20.0
ExternalViewAngleMin = 3.0
ExternalViewAngleMax = 170.0
ExternalViewAngleDefault = 120.0
ExternalKeyboardZoomAcceleration = 30.0
ExternalKeyboardZoomAccelerateTimeMax = 1.0
ExplosionExpoTime = 4.0
ExternalKeyboardAccelerationSlow = 1.0
ExternalKeyboardAccelerationNormal = 10.0
ExternalKeyboardAccelerationFast = 30.0
ExternalHAngleAccelerateTimeMax = 3.0
ExternalVAngleAccelerateTimeMax = 3.0
ExternalDistAccelerateTimeMax = 3.0
ExternalHAngleLocalAccelerateTimeMax = 3.0
ExternalVAngleLocalAccelerateTimeMax = 3.0
ExternalAngleNormalDiscreteStep = 15.0/ExternalKeyboardAccelerationNormal -- When 'S' is pressed only
ChaseCameraNyMove = true
FreeCameraAngleIncrement = 3.0
FreeCameraDistanceIncrement = 200.0
FreeCameraLeftRightIncrement = 2.0
FreeCameraAltitudeIncrement = 2.0
FreeCameraScalarSpeedAcceleration = 0.1 
xMinMap = -300000
xMaxMap = 500000
yMinMap = -400000
yMaxMap = 200000
dxMap = 150000
dyMap = 100000

head_roll_shaking = true
head_roll_shaking_max = 30.0
head_roll_shaking_compensation_gain = 0.3

-- CameraJiggle() and CameraFloat() functions make camera position
-- dependent on FPS so be careful in using the Shift-J command with tracks, please.
-- uncomment to use custom jiggle functions
--[[
function CameraJiggle(t,rnd1,rnd2,rnd3)
	local rotX, rotY, rotZ
	rotX = 0.05 * rnd1 * math.sin(37.0 * (t - 0.0))
	rotY = 0.05 * rnd2 * math.sin(41.0 * (t - 1.0))
	rotZ = 0.05 * rnd3 * math.sin(53.0 * (t - 2.0))
	return rotX, rotY, rotZ
end

function CameraFloat(t)
	local dX, dY, dZ
	dX = 0.61 * math.sin(0.7 * t) + 0.047 * math.sin(1.6 * t);
	dY = 0.43 * math.sin(0.6 * t) + 0.067 * math.sin(1.7 * t);
	dZ = 0.53 * math.sin(1.0 * t) + 0.083 * math.sin(1.9 * t);
	return dX, dY, dZ
end
--]]
--Debug keys

DEBUG_TEXT 		= 1
DEBUG_GEOMETRY 	= 2

debug_keys = {
	[DEBUG_TEXT] = 1,
	[DEBUG_GEOMETRY] = 1
}

function onDebugCommand(command)
	if command == 10000 then		
		if debug_keys[DEBUG_TEXT] ~= 0 or debug_keys[DEBUG_GEOMETRY] ~= 0 then
			debug_keys[DEBUG_GEOMETRY] = 0
			debug_keys[DEBUG_TEXT] = 0
		else
			debug_keys[DEBUG_GEOMETRY] = 1
			debug_keys[DEBUG_TEXT] = 1		
		end	
	elseif command == 10001 then 
		if debug_keys[DEBUG_TEXT] ~= 0 then
			debug_keys[DEBUG_TEXT] = 0
		else
			debug_keys[DEBUG_TEXT] = 1
		end		
	elseif command == 10002 then
		if debug_keys[DEBUG_GEOMETRY] ~= 0 then
			debug_keys[DEBUG_GEOMETRY] = 0
		else
			debug_keys[DEBUG_GEOMETRY] = 1
		end
	end
end
