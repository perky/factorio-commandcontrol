SECONDS = 60
MINUTES = 3600
require("defines")
require("util")
require("helpers.helpers")
require("helpers.gui_helpers")
require("helpers.coroutine_helpers")
require("radar_system")

local radar_system

local function OnGameInit()
	radar_system = RadarSystem.CreateActor()
	radar_system:Init()
end

local function OnGameSave()
	glob.radar_system = radar_system
end

local function OnGameLoad()
	if glob.radar_system then
		radar_system = RadarSystem.CreateActor(glob.radar_system)
		radar_system:OnLoad()
	end
end

local function OnPlayerCreated( playerindex )
	local player = game.players[playerindex]
	radar_system:OnPlayerCreated(player)
end

local function OnEntityBuilt( entity, playerindex )
	local player
	if playerindex then
		player = game.players[playerindex]
	end

	if entity.name == "radar" and player then
		radar_system:OnRadarBuilt(entity, player)
	end
end

local function OnEntityDestroy( entity, playerindex )
	local player
	if playerindex then
		player = game.players[playerindex]
	end

	if entity.name == "radar" and player then
		radar_system:OnRadarDestroy(entity, player)
	end
end

local function OnTick()
	ResumeRoutines()
	radar_system:OnTick()
end

game.oninit(OnGameInit)
game.onload(OnGameLoad)
game.onsave(OnGameSave)
game.onevent(defines.events.onbuiltentity, function(event) OnEntityBuilt(event.createdentity, event.playerindex) end)
game.onevent(defines.events.onrobotbuiltentity, function(event) OnEntityBuilt(event.createdentity) end)
game.onevent(defines.events.onentitydied, function(event) OnEntityDestroy(event.entity) end)
game.onevent(defines.events.onpreplayermineditem, function(event) OnEntityDestroy(event.entity, event.playerindex) end)
game.onevent(defines.events.onrobotpremined, function(event) OnEntityDestroy(event.entity) end)
game.onevent(defines.events.onplayercreated, function(event) OnPlayerCreated(event.playerindex) end)
game.onevent(defines.events.ontick, OnTick)