ActorClass("RadarSystem", {
	gui_activation_distance = 3,
	ranges={["radar"]=3*32}--to support modded radars that would be better done in separate file
})

function RadarSystem:Init()
	self.enabled = true
	self.radars = {}
	self.renames = {}
	self.gui = {}
	self.rename_gui = {}
	self.buttons = {}
	self.nearby_radar = {}
	self.viewing_radar = {}
	self.player_character = {}
	-- added in 1.1.0
	self.filtered_radars = {}
	self.search_term = {}
	self.visit_count = {}
	--
	StartCoroutine(self.UpdateGUIRoutine, self)
end

function RadarSystem:OnLoad()
	self.enabled = true
	
	if not self.filtered_radars then
		self.filtered_radars = {}
	end
	if not self.search_term then
		self.search_term = {}
	end
	if not self.visit_count then
		self.visit_count = {}
	end

	-- remove invalid radars.
	for i = #self.radars, 1, -1 do
		local radar = self.radars[i]
		if not radar.valid then
			table.remove(self.radars, i)
		end
	end

	StartCoroutine(self.UpdateGUIRoutine, self)
end

function RadarSystem:OnDestroy()
	self.enabled = false
end

function RadarSystem:CheckPlayerIsNearRadar( player )
	if self.viewing_radar[player.name] then
		return
	end

	local nearbyRadar = self.nearby_radar[player.name]
	if nearbyRadar and not nearbyRadar.valid then
		if self.gui[player.name] then self:CloseGUI(player) end
		self.nearby_radar[player.name] = nil
	elseif nearbyRadar and nearbyRadar.valid then
		local dist = util.distance(player.position, self.nearby_radar[player.name].position)
		if dist > self.gui_activation_distance + 2 then
			if self.gui[player.name] then self:CloseGUI(player) end
			self.nearby_radar[player.name] = nil
		end
	else
		local searchArea = SquareArea(player.position, self.gui_activation_distance)
		local nearRadars = player.surface.find_entities_filtered{area = searchArea, name = "radar"}
		if #nearRadars > 0 then
			self.nearby_radar[player.name] = nearRadars[1]
			if not self.gui[player.name] then 
				self:OpenGUI(player)
			end
		end
	end
end

function RadarSystem:UpdateGUIRoutine()
	WaitForTicks(1*SECONDS)

	for playerIndex, player in ipairs(game.players) do
		if self.gui[player.name] then
			self:CloseGUI(player)
			self:OpenGUI(player)
		end
	end

	WaitForTicks(1*SECONDS)

	while self.enabled do
		for playerIndex, player in ipairs(game.players) do
			if self.gui[player.name] then
				self:UpdateGUI(player)
			end
		end
		WaitForTicks(1*SECONDS)
	end
end

function RadarSystem:OnTick()
	for playerIndex, player in ipairs(game.players) do
		local viewingRadar = self.viewing_radar[player.name]
		local nearbyRadar = self.nearby_radar[player.name]

		if (viewingRadar and not viewingRadar.valid) or (nearbyRadar and not nearbyRadar.valid) then
			self:ExitRadarViewer(player)
			self:CloseGUI(player)
		else
			if viewingRadar and viewingRadar.valid and nearbyRadar and nearbyRadar.valid then
				if viewingRadar.energy > 1 and nearbyRadar.energy > 1 then
					player.teleport(viewingRadar.position)
				else
					self:ExitRadarViewer(player)
					self:CloseGUI(player)
				end
			end
		end

		if game.tick % (1*SECONDS) == 0 then
			self:CheckPlayerIsNearRadar(player)
		end
	end
end

function RadarSystem:EnterRadarViewer( data )
	local radar = data.radar
	local player = data.player

	if not radar.valid or radar.energy < 1 then return end

	player.print("Viewing radar "..radar.backer_name..".")

	-- Remove the player's items if we switch to a different radar.
	-- This is to prevent player's from using the cc system to transfer items over
	-- long distances. If you want that, remove the next three lines.
	if self.viewing_radar[player.name] and radar ~= self.viewing_radar[player.name] then
		player.clear_items_inside()
	end

	self.viewing_radar[player.name] = radar
	if not self.player_character[player.name] then
		self.player_character[player.name] = player.character
		player.character = nil
	end
	self:CloseGUI(player)
	self:OpenGUI(player)

	if not self.visit_count[radar.backer_name] then
		self.visit_count[radar.backer_name] = 1
	else
		self.visit_count[radar.backer_name] = self.visit_count[radar.backer_name] + 1
	end
end

function RadarSystem:ExitRadarViewer( player )
	if self.player_character[player.name] then
		player.print("Exiting rader viewer.")
		player.character = self.player_character[player.name]
		self.player_character[player.name] = nil
		self.viewing_radar[player.name] = nil
	end
end

function RadarSystem:RemoveInvalidRadars( radarList )
	for index = #radarList, 1, -1 do
		local radar = radarList[index]
		if radar and not radar.valid then
			table.remove(radarList, index)
		end
	end
	return radarList
end

function RadarSystem:SortRadarsByVisitCount( radarA, radarB )
	local visitA = self.visit_count[radarA.backer_name]
	local visitB = self.visit_count[radarB.backer_name]
	if visitA == nil then
		visitA = 0
	end
	if visitB == nil then
		visitB = 0
	end
	return visitA > visitB
end

function RadarSystem:FilterSearch( player, forceRefresh )
	local myGui = self.gui[player.name]
	if not myGui then
		return
	end

	local searchInput = string.lower(myGui.search_flow.search.text)
	lastSearchTerm = self.search_term[player.name]
	self.search_term[player.name] = searchInput
	self.filtered_radars[player.name] = self.radars
	local searchTermChanged = false

	if lastSearchTerm ~= searchInput then
		if searchInput and searchInput ~= "" then
			local filteredRadars = {}
			for i, radar in ipairs(self.radars) do
				local radarName = string.lower(self:GetRadarName(radar))
				if string.find(radarName, searchInput) then
					table.insert(filteredRadars, radar)
				end
			end
			self.filtered_radars[player.name] = filteredRadars
		else
			self.filtered_radars[player.name] = self.radars
		end

		searchTermChanged = true
	end

	if forceRefresh or searchTermChanged and self.filtered_radars[player.name] then
		self.filtered_radars[player.name] = self:RemoveInvalidRadars(self.filtered_radars[player.name])
		table.sort(self.filtered_radars[player.name], function(a, b) return self:SortRadarsByVisitCount(a,b) end)

		GUI.PushParent(myGui)
		self:DestroyRadarButtons(player)
		self:AddRadarButtons(player)
		GUI.PopAll()
	end
end

function RadarSystem:OpenGUI( player )
	if self.gui[player.name] then
		return
	end

	GUI.PushParent(player.gui.left)
		self.gui[player.name] = GUI.PushParent(GUI.Frame("radarsys_gui", "Command Control", GUI.VERTICAL))
			GUI.PushParent(GUI.Flow("main_buttons", GUI.HORIZONTAL))
				local currentRadar = self.nearby_radar[player.name]
				if self.viewing_radar[player.name] then
					GUI.Button("exit", "Exit", "ExitRadarViewer", self, player)
					currentRadar = self.viewing_radar[player.name]
				end
				local currentRadarName = self:GetRadarName(currentRadar)
				GUI.Button("rename", "Rename "..currentRadarName, "OpenRenameGUI", self, player)
			GUI.PopParent()

			GUI.PushParent(GUI.Flow("search_flow", GUI.HORIZONTAL))
				GUI.Label("search_label", "Search:")
				local search = GUI.TextField("search", "")
				search.text = self.search_term[player.name] or ""
			GUI.PopParent()
			
			self:FilterSearch(player, true)

	GUI.PopAll()
end

function RadarSystem:DestroyRadarButtons( player )
	if self.gui[player.name].radar_buttons then
		self.gui[player.name].radar_buttons.destroy()
	end
end

function RadarSystem:AddRadarButtons( player )
	self.buttons[player.name] = {}
	local radars = self.filtered_radars[player.name]
	GUI.PushParent(GUI.Flow("radar_buttons", GUI.VERTICAL))
	for i, radar in ipairs(radars) do
		if i > 27 and i < #radars then
			local difference = (#radars - i) + 1
			GUI.Label("end_results", string.format("%d more...", difference))
			break
		end
		if (i % 3) == 1 then
			if i > 1 then
				GUI.PopParent()
			end
			GUI.PushParent(GUI.Flow("buttons_"..i, GUI.HORIZONTAL))
		end
		radarname = self:GetRadarName(radar)
		local btn = GUI.Button("view_radar_"..i, radarname, "EnterRadarViewer", self, {radar = radar, player = player})
		btn.style = "cc_radar_button_style"
		self.buttons[player.name][i] = {["button"] = btn, ["radar"] = radar}
	end
	GUI.PopAfter("radar_buttons")
end

function RadarSystem:CloseGUI( player )
	if self.gui[player.name] then
		self.gui[player.name].destroy()
		self.gui[player.name] = nil
	end
end

function RadarSystem:UpdateGUI( player )
	if not self.gui[player.name] then return end

	self:FilterSearch(player)

	for i, entry in ipairs(self.buttons[player.name]) do
		local radar = entry.radar
		local button = entry.button
		if (radar and not radar.valid) then
			self:RemoveRadar(radar)
			self:CloseGUI(player)
			self:OpenGUI(player)
			return
		elseif radar.energy > 1 then
			button.style = "cc_radar_button_style"
		else
			button.style = "cc_radar_button_disabled_style"
		end
	end
end

function RadarSystem:OpenRenameGUI( player )
	local radar = self.nearby_radar[player.name]
	if self.viewing_radar[player.name] then radar = self.viewing_radar[player.name] end
	local radarname = self:GetRadarName(radar)
	GUI.PushParent(player.gui.center)
		self.rename_gui[player.name] = GUI.PushParent(GUI.Frame("radar_rename", "Rename "..radarname, GUI.VERTICAL))
			GUI.TextField("rename_input", radar.backer_name)
			GUI.Button("done", "Done", "OnRenameDone", self, player)
		GUI.PopParent()
	GUI.PopParent()
end

function RadarSystem:OnRenameDone( player )
	local radar = self.nearby_radar[player.name]
	if self.viewing_radar[player.name] then radar = self.viewing_radar[player.name] end
	local newName = self.rename_gui[player.name].rename_input.text
	if newName ~= "" then
		self.visit_count[newName] = self.visit_count[radar.backer_name]
		radar.backer_name = newName;
	end
	self.rename_gui[player.name].destroy()
	self:CloseGUI(player)
	self:OpenGUI(player)
end

function RadarSystem:GetRadarName( radar )
	if not radar or (radar and not radar.valid) then
		return "NIL"
	else
		return radar.backer_name
	end
end

function RadarSystem:OnRadarBuilt( radarEntity, player )
	table.insert(self.radars, radarEntity)
	if player and self.gui[player.name] then
		self:CloseGUI(player)
		self:OpenGUI(player)
	end
end

function RadarSystem:RemoveRadar( radarToRemove )
	for i, radar in ipairs(self.radars) do
		if radar == radarToRemove then
			table.remove(self.radars, i)
			break
		end
	end
end

function RadarSystem:OnRadarDestroy( radarEntity, player )
	local removedRadar = nil
	for i, radar in ipairs(self.radars) do
		if radar == radarEntity then
			table.remove(self.radars, i)
			removedRadar = radar
			break
		end
	end

	if removedRadar and self.nearby_radar[player.name] and self.nearby_radar[player.name] == removedRadar then
		self:CloseGUI(player)
	end
end

function RadarSystem:OnOtherEntityDestroy(entity)
	--need to determine whether it was in range of one of supported radars
	for _,radar in pairs(self.radars) do
		if radar.valid and (entity.force==radar.force) then--this one should probably be done before entering the cycle, when mod stores different forces separately
			if InSquare(entity.position,radar.position,self.ranges[radar.name]) then
				Message({"",entity.localised_name," ",{"com-con-mes-destroyed"}," ",{"com-con-mes-near"}," ",radar.backer_name}, entity.force)
				break
			end
        elseif not radar.valid then table.remove(self.radars,_)
		end
	end
end
