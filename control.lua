SECONDS = 60
MINUTES = 3600
require("defines")
require("util")
require("helpers.helpers")
require("helpers.gui_helpers")
require("helpers.coroutine_helpers")
require("radar_system")

local radar_system, mod_has_init

local function OnGameInit()
	radar_system = RadarSystem.CreateActor()
	radar_system:Init()
	mod_has_init = true
end

local function OnGameSave()
	global.radar_system = radar_system
end

local function OnGameLoad()
	if not mod_has_init and global.radar_system then
		radar_system = RadarSystem.CreateActor(global.radar_system)
		radar_system:OnLoad()
		mod_has_init = true
	end
	if global.radar_system and not global.radar_system.ranges then --this is my quasimigration since I've added a new field
		global.radar_system.ranges={["radar"]=3*32} --it'll probably have to be handled in differrent way soon
	end
end

local function OnPlayerCreated( playerindex )
	local player = game.players[playerindex]
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
	else
        	radar_system:OnOtherEntityDestroy(entity)
	end
end

local function OnTick()
	ResumeRoutines()
	radar_system:OnTick()
end

game.on_init(OnGameInit)
game.on_load(OnGameLoad)
game.on_save(OnGameSave)
game.on_event(defines.events.on_built_entity, function(event) OnEntityBuilt(event.created_entity, event.player_index) end)
game.on_event(defines.events.on_robot_built_entity, function(event) OnEntityBuilt(event.created_entity) end)
game.on_event(defines.events.on_entity_died, function(event) OnEntityDestroy(event.entity) end)
game.on_event(defines.events.on_preplayer_mined_item, function(event) OnEntityDestroy(event.entity, event.player_index) end)
game.on_event(defines.events.on_robot_pre_mined, function(event) OnEntityDestroy(event.entity) end)
game.on_event(defines.events.on_player_created, function(event) OnPlayerCreated(event.player_index) end)
game.on_event(defines.events.on_tick, OnTick)
