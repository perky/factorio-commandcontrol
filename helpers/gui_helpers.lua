GUI = {
	parentStack = {},
	buttonCallbacks = {}
}
GUI.VERTICAL = "vertical"
GUI.HORIZONTAL = "horizontal"

function GUI.PushLeftSection()
	return GUI.PushParent(game.player.gui.left)
end

function GUI.PushParent( parent )
	table.insert(GUI.parentStack, parent)
	return parent
end

function GUI.PopParent()
	table.remove(GUI.parentStack, #GUI.parentStack)
end

function GUI.PopAfter( elementName )
	while #GUI.parentStack > 0 and GUI.Parent().name ~= elementName do
		GUI.PopParent()
	end
	if GUI.Parent().name == elementName then
		GUI.PopParent()
	end
end

function GUI.PopAll()
	GUI.parentStack = {}
end

function GUI.Parent()
	return GUI.parentStack[#GUI.parentStack]
end

function GUI.Frame(name, caption, direction)
	if direction == nil then
		direction = GUI.VERTICAL
	end
	local parent = GUI.Parent()
	if not parent[name] then
		return GUI.Parent().add{type = "frame", name=name, caption=caption, direction = direction}
	else
		return parent[name]
	end
end

function GUI.Label(name, caption, style)
	return GUI.Parent().add{type = "label", name = name, caption = caption, style = style}
end

function GUI.SetLabelCaptionLocalised( label, ... )
	local texts = {...}
	table.insert(texts, 1, "")
	label.caption = texts
end

function GUI.LabelData(name, caption, initialValue)
	local flow = GUI.PushParent(GUI.Flow(name, GUI.HORIZONTAL))
	GUI.Label("label", caption, "caption_label_style")
	GUI.Label("data", initialValue, "description_title_label_style")
	GUI.PopParent()
	return flow
end

function GUI.ProgressBar(name, size, initialValue, style)
	return GUI.Parent().add{
		type = "progressbar",
		name = name,
		size = size,
		value = initialValue,
		style = style
	}
end

function GUI.Flow(name, direction)
	return GUI.Parent().add{type = "flow", name = name, direction = direction}
end

function GUI.Icon(name, iconName)
	return GUI.Parent().add{type = "checkbox", style = "arcology-icon-"..iconName, state = false, name = name}
end

function GUI.TextField(name, defaultText)
	if defaultText == nil then
		defaultText = ""
	end
	return GUI.Parent().add{type = "textfield", name = name, text = defaultText}
end

function GUI.Button(name, caption, methodName, delegate, args)
	local parent = GUI.Parent()
	local button = parent.add{type = "button", name = name, caption = caption, style = style}
	GUI.buttonCallbacks[name] = {onclick = methodName, delegate = delegate, args = args}
	return button
end

function GUI.DestroyButton( button )
	GUI.buttonCallbacks[button.name] = nil
	button.destroy()
end

function GUI.OnClick( event )
	local element = event.element
	local callback = GUI.buttonCallbacks[element.name]
	if callback then
		local func = callback.delegate[callback.onclick]
		if func then
			func(callback.delegate, callback.args)
		end
	end
end
script.on_event(defines.events.on_gui_click, GUI.OnClick)
