SECONDS = 60
MINUTES = 3600
require("defines")
require("util")
require("helpers.helpers")
require("helpers.gui_helpers")
require("helpers.coroutine_helpers")
require("radar_system")

local mod_has_init

local function OnGameInit()
	global.radar_system = RadarSystem.CreateActor()
	global.radar_system:Init()
	mod_has_init = true
end

local function OnGameLoad()
	if not mod_has_init and global.radar_system then
		global.radar_system = RadarSystem.CreateActor(global.radar_system)
		global.radar_system:OnLoad()
		mod_has_init = true
	end
end

local function Migration_1_1_2()
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
		global.radar_system:OnRadarBuilt(entity, player)
	end
end

local function OnEntityDestroy( entity, playerindex )
	local player
	if playerindex then
		player = game.players[playerindex]
	end

	if entity.name == "radar" and player then
		global.radar_system:OnRadarDestroy(entity, player)
	end
end

local function Messaging(entity)
    if entity.name == "radar" then 
        Message({'',entity.localised_name," ",entity.backer_name," ",{"com-con-mes-destroyed"},entity.force})
    else
        global.radar_system:OnOtherEntityDestroy(entity)
    end
end

local function OnTick()
	ResumeRoutines()
	global.radar_system:OnTick()
end

script.on_init(OnGameInit)
script.on_load(OnGameLoad)
script.on_configuration_changed(Migration_1_1_2)--here probably should be some more sophistication, but it'll wait till we get documentation on that 
script.on_event(defines.events.on_built_entity, function(event) OnEntityBuilt(event.created_entity, event.player_index) end)
script.on_event(defines.events.on_robot_built_entity, function(event) OnEntityBuilt(event.created_entity) end)
script.on_event(defines.events.on_entity_died, function(event) OnEntityDestroy(event.entity); Messaging(event.entity); end)
script.on_event(defines.events.on_preplayer_mined_item, function(event) OnEntityDestroy(event.entity, event.player_index);end)
script.on_event(defines.events.on_robot_pre_mined, function(event) OnEntityDestroy(event.entity) end)
script.on_event(defines.events.on_player_created, function(event) OnPlayerCreated(event.player_index) end)
script.on_event(defines.events.on_tick, OnTick)
