local dscreen = {}

local h_nil = hash("nil")
local h_load = hash("load")
local h_init = hash("init")
local h_enable = hash("enable")
local h_acquire_input_focus = hash("acquire_input_focus")
local h_unload = hash("unload")
local h_final = hash("final")
local h_disable = hash("disable")
local h_release_input_focus = hash("release_input_focus")
local h_set_time_step = hash("set_time_step")
local h_proxy_loaded = hash("proxy_loaded")
local h_proxy_unloaded = hash("proxy_unloaded")

dscreen.screen_types = {
	basic,
	pause,
	toolbar
}

dscreen.msg = {
	
}

dscreen.registered_screens = {}
dscreen.screen_stack = {}

function dscreen.register_screen(screen_id, screen_type, proxy_url, script_url)
	dscreen.registered_screens[screen_id] = {
		screen_id = screen_id,
		screen_type = screen_type,
		proxy_url = proxy_url,
		script_url = script_url,
		is_pushed = false,
		is_loaded = false,
		is_loading = false,
		is_unloading = false,
		is_initialized = false,
		is_enabled = false,
		is_paused = false,
		has_input = false,
		parent_release = h_nil,
		parent_disable = h_nil,
		parent_final = h_nil,
		parent_unload = h_nil,
		parent_pause = h_nil,
		data = {}
	}
end

function dscreen.unregister_screen(screen_id)
	dscreen.registered_screens[screen_id] = nil
end

function dscreen.push_screen(screen_id)
	if not dscreen.registered_screens[screen_id].is_pushed then
		if dscreen.registered_screens[screen_id].is_loaded then
			msg.post(dscreen.registered_screens[screen_id].proxy_url, h_init)
			dscreen.registered_screens[screen_id].is_initialized = true
			msg.post(dscreen.registered_screens[screen_id].proxy_url, h_enable)
			dscreen.registered_screens[screen_id].is_enabled = true
			msg.post(dscreen.registered_screens[screen_id].proxy_url, h_acquire_input_focus)
			dscreen.registered_screens[screen_id].has_input = true
		else
			msg.post(dscreen.registered_screens[screen_id].proxy_url, h_load)
			dscreen.registered_screens[screen_id].is_loading = true
		end
		if dscreen.registered_screens[screen_id].screen_type == dscreen.screen_types.basic then
			for i = 1, #dscreen.screen_stack do
				local screen_info = dscreen.registered_screens[dscreen.screen_stack[i]]
				if screen_info.parent_release == h_nil then
					msg.post(screen_info.proxy_url, h_release_input_focus)
					screen_info.has_input = false
					screen_info.parent_release = screen_id
				end
				if screen_info.parent_disable == h_nil then
					msg.post(screen_info.proxy_url, h_disable)
					screen_info.is_enabled = false
					screen_info.parent_disable = screen_id
				end
				if screen_info.parent_final == h_nil then
					msg.post(screen_info.proxy_url, h_final)
					screen_info.is_initialized = false
					screen_info.parent_final = screen_id
				end
				if screen_info.parent_pause == h_nil then
					msg.post(screen_info.proxy_url, h_set_time_step, { factor = 0, mode = 0 })
					screen_info.is_paused = false
					screen_info.parent_pause = screen_id
				end
				if screen_info.parent_unload == h_nil then
					msg.post(screen_info.proxy_url, h_unload)
					screen_info.is_unloading = true
					screen_info.parent_unload = screen_id
				end
			end
		elseif dscreen.registered_screens[screen_id].screen_type == dscreen.screen_types.pause then
			local screen_info = dscreen.registered_screens[dscreen.screen_stack[i]]
			if screen_info.parent_release == h_nil then
				msg.post(screen_info.proxy_url, h_release_input_focus)
				screen_info.has_input = false
				screen_info.parent_release = screen_id
			end
			if screen_info.parent_pause == h_nil then
				msg.post(screen_info.proxy_url, h_set_time_step, { factor = 0, mode = 0 })
				screen_info.is_paused = false
				screen_info.parent_pause = screen_id
			end
		end
		table.insert(dscreen.screen_stack, screen_id)
		dscreen.registered_screens[screen_id].is_pushed = true
	end
end

function dscreen.pop_screen(count)
	if #dscreen.screen_stack > 0 then
		
	end
end

function dscreen.set_screen_data(screen_id, data)
	if dscreen.registered_screens[screen_id] then
		dscreen.registered_screens[screen_id].data = data
	end
end

function dscreen.get_screen_data(screen_id)
	if dscreen.registered_screens[screen_id] then
		return dscreen.registered_screens[screen_id].data
	end
end

function dscreen.on_message(message_id, message, sender)
	if message_id == h_proxy_loaded then
		msg.post(sender, h_init)
		msg.post(sender, h_enable)
		msg.post(sender, h_acquire_input_focus)
		for key, value in pairs(dscreen.registered_screens) do
			if value.proxy_url == sender then
				value.is_loading = false
				value.is_loaded = true
				value.is_initialized = true
				value.is_enabled = true
				value.has_input = true
			end
		end
	elseif message_id == h_proxy_unloaded then
		for key, value in pairs(dscreen.registered_screens) do
			if value.proxy_url == sender then
				value.is_unloading = false
				value.is_loaded = false
			end
		end
	end
end

return dscreen