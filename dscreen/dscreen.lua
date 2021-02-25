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
	basic = 1,
	pause = 2,
	toolbar = 3
}

dscreen.msg = {
	pushed_in = hash("pushed_in"),
	pushed_out = hash("pushed_out"),
	popped_in = hash("popped_in"),
	popped_out = hash("popped_out")
}

dscreen.registered_screens = {}
dscreen.screen_stack = {}

local function has_script_url(screen_id)
	return dscreen.registered_screens[screen_id].script_url ~= ""
end

function dscreen.register_screen(screen_id, screen_type, proxy_url, script_url)
	dscreen.registered_screens[screen_id] = {
		screen_id = screen_id,
		screen_type = screen_type,
		proxy_url = proxy_url,
		script_url = script_url or "",
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
			if has_script_url(screen_id) then
				msg.post(dscreen.registered_screens[screen_id].script_url, dscreen.msg.pushed_in)
			end
		else
			msg.post(dscreen.registered_screens[screen_id].proxy_url, h_load)
			dscreen.registered_screens[screen_id].is_loading = true
		end
		if dscreen.registered_screens[screen_id].screen_type == dscreen.screen_types.basic then
			for i = 1, #dscreen.screen_stack do
				local is_affected = false
				local screen_info = dscreen.registered_screens[dscreen.screen_stack[i]]
				if screen_info.parent_release == h_nil then
					msg.post(screen_info.proxy_url, h_release_input_focus)
					screen_info.has_input = false
					screen_info.parent_release = screen_id
					is_affected = true
				end
				if screen_info.parent_disable == h_nil then
					msg.post(screen_info.proxy_url, h_disable)
					screen_info.is_enabled = false
					screen_info.parent_disable = screen_id
					is_affected = true
				end
				if screen_info.parent_final == h_nil then
					msg.post(screen_info.proxy_url, h_final)
					screen_info.is_initialized = false
					screen_info.parent_final = screen_id
					is_affected = true
				end
				if screen_info.parent_pause == h_nil then
					msg.post(screen_info.proxy_url, h_set_time_step, { factor = 0, mode = 0 })
					screen_info.is_paused = false
					screen_info.parent_pause = screen_id
					is_affected = true
				end
				if is_affected then
					msg.post(screen_info.script_url, dscreen.msg.pushed_out)
				end
			end
		elseif dscreen.registered_screens[screen_id].screen_type == dscreen.screen_types.pause then
			for i = 1, #dscreen.screen_stack do
				local is_affected = false
				local screen_info = dscreen.registered_screens[dscreen.screen_stack[i]]
				if screen_info.parent_release == h_nil then
					msg.post(screen_info.proxy_url, h_release_input_focus)
					screen_info.has_input = false
					screen_info.parent_release = screen_id
					is_affected = true
				end
				if screen_info.parent_pause == h_nil then
					msg.post(screen_info.proxy_url, h_set_time_step, { factor = 0, mode = 0 })
					screen_info.is_paused = false
					screen_info.parent_pause = screen_id
					is_affected = true
				end
				if is_affected then
					msg.post(screen_info.script_url, dscreen.msg.pushed_out)
				end
			end
		end
		table.insert(dscreen.screen_stack, screen_id)
		dscreen.registered_screens[screen_id].is_pushed = true
	end
end

function dscreen.pop_screen(count)
	if not count then
		count = 1
	elseif count > #dscreen.screen_stack then
		count = #dscreen.screen_stack
	end
	if #dscreen.screen_stack > 0 then
		for i = 1, count do
			local screen_info = dscreen.registered_screens[dscreen.screen_stack[#dscreen.screen_stack]]
			if screen_info.is_paused then
				msg.post(screen_info.proxy_url, h_set_time_step, { factor = 1, mode = 0 })
				screen_info.is_paused = false
			else
				screen_info.parent_pause = h_nil
			end
			if screen_info.has_input then
				msg.post(screen_info.proxy_url, h_release_input_focus)
				screen_info.has_input = false
			else
				screen_info.parent_release = h_nil
			end
			if screen_info.is_enabled then
				msg.post(screen_info.proxy_url, h_disable)
				screen_info.is_enabled = false
			else
				screen_info.parent_disable = h_nil
			end
			if screen_info.is_initialized then
				msg.post(screen_info.proxy_url, h_final)
				screen_info.is_initialized = false
			else
				screen_info.parent_final = h_nil
			end
			table.remove(dscreen.screen_stack, #dscreen.screen_stack)
			screen_info.is_pushed = false
			if has_script_url(screen_info.screen_id) then
				msg.post(screen_info.script_url, dscreen.msg.popped_out)
			end
		end
		for i = 1, #dscreen.screen_stack do
			local is_affected = false
			local screen_info = dscreen.registered_screens[dscreen.screen_stack[i]]
			if screen_info.parent_release ~= h_nil and not dscreen.registered_screens[screen_info.parent_release].is_pushed then
				msg.post(screen_info.proxy_url, h_acquire_input_focus)
				screen_info.has_input = true
				screen_info.parent_release = h_nil
				is_affected = true
			end
			if screen_info.parent_final ~= h_nil and not dscreen.registered_screens[screen_info.parent_final].is_pushed then
				msg.post(screen_info.proxy_url, h_init)
				screen_info.is_initialized = true
				screen_info.parent_final = h_nil
				is_affected = true
			end
			if screen_info.parent_disable ~= h_nil and not dscreen.registered_screens[screen_info.parent_disable].is_pushed then
				msg.post(screen_info.proxy_url, h_enable)
				screen_info.is_enabled = true
				screen_info.parent_disable = h_nil
				is_affected = true
			end
			if screen_info.parent_pause ~= h_nil and not dscreen.registered_screens[screen_info.parent_pause].is_pushed then
				msg.post(screen_info.proxy_url, h_set_time_step, { factor = 1, mode = 0 })
				screen_info.is_paused = false
				screen_info.parent_pause = h_nil
				is_affected = true
			end
			if is_affected then
				msg.post(screen_info.script_url, dscreen.msg.popped_in)
			end
		end
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
				if has_script_url(value.screen_id) then
					msg.post(value.script_url, dscreen.msg.pushed_in)
				end
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