ActorClass("RadarSystem", {
	gui_activation_distance = 3
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
end

function RadarSystem:OnLoad()
	self.enabled = true
	for playerIndex, player in ipairs(game.players) do
		StartCoroutine(function() self:CheckPlayerIsNearRoutine(player) end)
	end
end

function RadarSystem:OnDestroy()
	self.enabled = false
end

function RadarSystem:OnPlayerCreated( player )
	StartCoroutine(function() self:CheckPlayerIsNearRoutine(player) end)
end

function RadarSystem:CheckPlayerIsNearRoutine( player )
	while self.enabled and not self.viewing_radar[player.name] do
		if self.nearby_radar[player.name] then
			local dist = util.distance(player.position, self.nearby_radar[player.name].position)
			if dist > self.gui_activation_distance + 2 then
				if self.gui then self:CloseGUI(player) end
				self.nearby_radar[player.name] = nil
			end
		else
			local searchArea = SquareArea(player.position, self.gui_activation_distance)
			local nearRadars = game.findentitiesfiltered{area = searchArea, name = "radar"}
			if #nearRadars > 0 then
				self.nearby_radar[player.name] = nearRadars[1]
				if not self.gui[player.name] then 
					self:OpenGUI(player)
				end
			end
		end

		WaitForTicks(1 * SECONDS)
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
			if self.gui[player.name] then
				self:UpdateGUI(player)
			end
		end
	end
end

function RadarSystem:EnterRadarViewer( data )
	local radar = data.radar
	local player = data.player

	if radar.energy < 1 then return end

	player.print("Viewing radar "..radar.backername..".")

	-- Remove the player's items if we switch to a different radar.
	-- This is to prevent player's from using the cc system to transfer items over
	-- long distances. If you want that, remove the next three lines.
	if self.viewing_radar[player.name] and radar ~= self.viewing_radar[player.name] then
		player.clearitemsinside()
	end

	self.viewing_radar[player.name] = radar
	if not self.player_character[player.name] then
		self.player_character[player.name] = player.character
		player.character = nil
	end
	self:CloseGUI(player)
	self:OpenGUI(player)
end

function RadarSystem:ExitRadarViewer( player )
	if self.player_character[player.name] then
		player.print("Exiting rader viewer.")
		player.character = self.player_character[player.name]
		self.player_character[player.name] = nil
		self.viewing_radar[player.name] = nil
		StartCoroutine(function() self:CheckPlayerIsNearRoutine(player) end)
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
			
			self.buttons[player.name] = {}
			for i, radar in ipairs(self.radars) do
				if (i % 3) == 1 then
					if i > 1 then
						GUI.PopParent()
					end
					GUI.PushParent(GUI.Flow("buttons_"..i, GUI.HORIZONTAL))
				end
				radarname = self:GetRadarName(radar)
				local btn = GUI.Button("view_radar_"..i, radarname, "EnterRadarViewer", self, {radar = radar, player = player})
				btn.style = "cc_radar_button_style"
				self.buttons[player.name][i] = btn
			end
	GUI.PopAll()
end

function RadarSystem:CloseGUI( player )
	if self.gui[player.name] then
		self.gui[player.name].destroy()
		self.gui[player.name] = nil
	end
end

function RadarSystem:UpdateGUI( player )
	for i, radar in ipairs(self.radars) do
		if radar.energy > 1 then
			self.buttons[player.name][i].style = "cc_radar_button_style"
		else
			self.buttons[player.name][i].style = "cc_radar_button_disabled_style"
		end
	end
end

function RadarSystem:OpenRenameGUI( player )
	local radar = self.nearby_radar[player.name]
	if self.viewing_radar[player.name] then radar = self.viewing_radar[player.name] end
	local radarname = self:GetRadarName(radar)
	GUI.PushParent(player.gui.center)
		self.rename_gui[player.name] = GUI.PushParent(GUI.Frame("radar_rename", "Rename "..radarname, GUI.VERTICAL))
			GUI.TextField("rename_input", radar.backername)
			GUI.Button("done", "Done", "OnRenameDone", self, player)
		GUI.PopParent()
	GUI.PopParent()
end

function RadarSystem:OnRenameDone( player )
	local radar = self.nearby_radar[player.name]
	if self.viewing_radar[player.name] then radar = self.viewing_radar[player.name] end
	local text = self.rename_gui[player.name].rename_input.text
	if text ~= "" then
		self.renames[radar.backername] = text
	end
	self.rename_gui[player.name].destroy()
	self:CloseGUI(player)
	self:OpenGUI(player)
end

function RadarSystem:GetRadarName( radar )
	if self.renames and self.renames[radar.backername] then
		return self.renames[radar.backername]
	else
		return radar.backername
	end
end

function RadarSystem:OnRadarBuilt( radarEntity, player )
	table.insert(self.radars, radarEntity)
	if player and self.gui[player.name] then
		self:CloseGUI(player)
		self:OpenGUI(player)
	end
end

function RadarSystem:OnRadarDestroy( radarEntity, player )
	local removedRadar = nil
	for i, radar in ipairs(self.radars) do
		if radar.equals(radarEntity) then
			table.remove(self.radars, i)
			removedRadar = radar
			break
		end
	end

	if removedRadar and self.nearby_radar[player.name] and self.nearby_radar[player.name].equals(removedRadar) then
		self:CloseGUI(player)
	end
end