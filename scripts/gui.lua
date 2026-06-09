---@type flib_gui
local flib_gui = require("__flib__.gui")
local gui_elements = require('scripts.gui-elements')

local GUI_SHORTCUT_BUTTON = 'circuit_radio_button_shortcut'
local GUI_ITEMS_PER_PAGE = 10

local gui = {}

------------------------------------------------------------
-- GUI EVENTS
------------------------------------------------------------

function gui.on_shortcut(e)
    if e.prototype_name == GUI_SHORTCUT_BUTTON then
        local player = game.get_player(e.player_index)

        if not player then
            return
        end

        local window = gui_elements.get_window(player)

        if window then
            window.destroy()
        else
            gui.create_window(player)
        end
    end
end

local function event_get_player_widow(e)
    local player = game.get_player(e.player_index)

    if not player then
        return
    end

    return gui_elements.get_window(player)
end

local function on_close_window(e)
    local window = event_get_player_widow(e)

    if window then
        window.destroy()
    end
end

local function on_channel_open(e)
    local player = game.get_player(e.player_index)
    if not player or not e.element.tags or not e.element.tags.channel_id then return end

    local clicked_button = e.element
    local channel_id = clicked_button.tags.channel_id

    if clicked_button.tags.is_active then return end

    local window = gui_elements.get_window(player)

    if window then
        local window_tags = window.tags or {}
        window_tags.current_channel = channel_id
        window_tags.stations_page = 1
        window.tags = window_tags
    end

    local channels_table = clicked_button.parent.parent
    if channels_table and channels_table.valid then
        for _, flow_element in pairs(channels_table.children) do
            if flow_element.valid and flow_element.type == "flow" then
                local button = flow_element.children[1]

                if button and button.valid and button.type == "sprite-button" then
                    button.style = "tool_button"

                    local button_tags = button.tags or {}
                    button_tags.is_active = false
                    button.tags = button_tags
                end
            end
        end
    end

    clicked_button.style = "flib_selected_tool_button"

    local c_tags = clicked_button.tags or {}
    c_tags.is_active = true
    clicked_button.tags = c_tags

    gui.load_tab_radios(window, channel_id, 1)
end

local function on_channels_prev(e)
    local window = event_get_player_widow(e)
    if not window then
        return
    end
    local current_tags = window.tags or {}
    local page = current_tags.channels_page or 1
    local prev_page = page - 1

    if page > 1 then
        current_tags.channels_page = prev_page
        window.tags = current_tags
        gui.load_tab_channels(window, prev_page)
    end
end

local function on_channels_next(e)
    local window = event_get_player_widow(e)
    if not window then
        return
    end
    local current_tags = window.tags or {}
    local page = current_tags.channels_page or 1
    local next_page = page + 1

    local total = storage.hubs and table_size(storage.hubs) or 0

    if page < math.ceil(total / GUI_ITEMS_PER_PAGE) then
        current_tags.channels_page = next_page
        window.tags = current_tags
        gui.load_tab_channels(window, next_page)
    end
end

local function on_radios_prev(e)
    local window = event_get_player_widow(e)

    if not window then
        return
    end

    local current_tags = window.tags or {}
    local page = current_tags.radios_page or 1
    local current_channel = current_tags.current_channel
    local prev_page = page - 1

    if page > 1 then
        current_tags.radios_page = prev_page
        window.tags = current_tags
        gui.load_tab_radios(window, current_channel, prev_page)
    end
end

local function on_radios_next(e)
    local window = event_get_player_widow(e)

    if not window then
        return
    end

    local current_tags = window.tags or {}
    local page = current_tags.radios_page or 1
    local current_channel = current_tags.current_channel
    local next_page = page + 1

    local radios = storage.channels and storage.channels[current_channel] and storage.channels[current_channel].radios
    local total = table_size(radios) or 0

    if page < math.ceil(total / GUI_ITEMS_PER_PAGE) then
        current_tags.radios_page = next_page
        window.tags = current_tags
        gui.load_tab_radios(window, current_channel, next_page)
    end
end

local function on_locate_radio_click(e)
    local player = game.get_player(e.player_index)
    local radio_id = e.element.tags and e.element.tags.radio_id

    if player and radio_id then
        local radio_data = storage.radios and storage.radios[radio_id]

        if radio_data and radio_data.entity and radio_data.entity.valid then
            local target_radio_entity = radio_data.entity
            local window = gui_elements.get_window(player)

            if window then
                window.destroy()
            end

            player.set_controller({
                type = defines.controllers.remote,
                position = target_radio_entity.position,
                surface = target_radio_entity.surface,
            })

            player.zoom = 3.0

            -- local display_name

            -- if player.surface.platform then
            --     display_name = player.surface.platform.name
            -- else
            --     display_name = { "space-location-name." .. player.surface.name }
            -- end

            local surface_name, surface_sprite = gui_elements.get_surface_name_and_sprite(player.surface)

            local select_box = target_radio_entity.prototype.selection_box
            local pos = target_radio_entity.position
            local left_top_pos = { pos.x + select_box.left_top.x, pos.y + select_box.left_top.y }
            local right_bottom_pos = { pos.x + select_box.right_bottom.x, pos.y + select_box.right_bottom.y }

            rendering.draw_rectangle({
                color = { r = 0.2, g = 1.0, b = 0.2, a = 0.7 },
                width = 2,
                filled = false,
                left_top = left_top_pos,
                right_bottom = right_bottom_pos,
                surface = target_radio_entity.surface,
                time_to_live = 120,
                players = { player },
            })

            player.print({
                "radio-interface.msg-zoomed",
                "[img=" .. surface_sprite .. "]",
                surface_name,
                target_radio_entity.position.x,
                target_radio_entity.position.y
            })
        else
            player.print({ "radio-interface.msg-error-dismantled" })
        end
    end
end

------------------------------------------------------------
-- GUI FUNCTIONS
------------------------------------------------------------

local function pagination_tab(pagination, page, total)
    local current_page = page or 1
    local total_pages = math.ceil(total / GUI_ITEMS_PER_PAGE)

    if current_page > total_pages then
        current_page = total_pages
    end

    pagination.visible = total_pages > 1
    if total_pages > 1 then
        pagination.page_label.caption = string.format(" %d / %d ", current_page, total_pages)
    end

    return pagination
end

local function load_page(table, pagination, items, current_page, row_fn, row_deleted_fn)
    local saved_index = pagination.tags.page_history[tostring(current_page)]

    local doIndex = tonumber(saved_index) or saved_index

    local displayed_count = 0

    if doIndex and items[doIndex] == nil then
        doIndex = nil
    end

    while displayed_count < GUI_ITEMS_PER_PAGE do
        local next_key = next(items, doIndex)

        if next_key == nil then
            break
        end

        doIndex = next_key
        local item = items[doIndex]

        if item then
            row_fn(table, doIndex, item)
        else
            row_deleted_fn(table)
        end

        displayed_count = displayed_count + 1
    end

    if doIndex then
        local current_tags = pagination.tags or {}
        local next_page_key = tostring(current_page + 1)
        local string_index = tostring(doIndex)

        if not current_tags.page_history[next_page_key] then
            current_tags.page_history[next_page_key] = string_index
            pagination.tags = current_tags
        end
    end
end

function gui.load_tab_radios(window, channel_id, page)
    local scroll_zone = gui_elements.get_radios_scroll_zone(window)
    scroll_zone.clear()

    local pagination = gui_elements.get_radios_pagination_flow(window)

    local current_channel_radios = storage.channels[channel_id] and storage.channels[channel_id].radios or {}
    local total_radios = table_size(current_channel_radios)

    if total_radios == 0 then
        flib_gui.add(scroll_zone, gui_elements.no_radios())
        pagination.visible = false
    end

    pagination_tab(pagination, page, total_radios)

    local radios_table = gui_elements.radios_head()

    local row = function(table_body, index, radio_value)
        local current_radio = storage.radios and storage.radios[index] or {}

        if current_radio.entity and current_radio.entity.valid then
            local entity = current_radio.entity
            local surface_name, surface_sprite = gui_elements.get_surface_name_and_sprite(entity.surface)

            return gui_elements.radios_row(table_body, index, surface_sprite, surface_name, on_locate_radio_click)
        end
    end

    local row_deleted = function(table_body)
        return gui_elements.radios_deleted_row(table_body)
    end

    load_page(radios_table, pagination, current_channel_radios, page, row, row_deleted)

    flib_gui.add(scroll_zone, radios_table)
end

function gui.load_tab_channels(window, page)
    local scroll_zone = gui_elements.get_channels_scroll_zone(window)
    scroll_zone.clear()

    local pagination = gui_elements.get_channels_pagination_flow(window)
    local current_active_channel = window.tags.current_channel
    local total_channels = table_size(storage.channels)

    if total_channels == 0 then
        flib_gui.add(scroll_zone, gui_elements.no_channels())
        pagination.visible = false
        return
    end

    pagination_tab(pagination, page, total_channels)

    local channels_table = gui_elements.channels_head()

    local row = function(table_body, index, channel)
        local count_radios = 0
        local is_selected = current_active_channel == index

        if channel.radios then
            count_radios = table_size(channel.radios)
        end

        return gui_elements.channels_row(table_body, index, count_radios, is_selected, on_channel_open)
    end

    local row_deleted = function(table_body)
        return gui_elements.channels_deleted_row(table_body)
    end

    load_page(channels_table, pagination, storage.channels, page, row, row_deleted)

    flib_gui.add(scroll_zone, channels_table)
end

function gui.create_window(player)
    local window = gui_elements.get_window(player)

    if window then
        return
    end

    window = flib_gui.add(
        player.gui.screen,
        gui_elements.window(
            on_close_window,
            on_channels_prev,
            on_channels_next,
            on_radios_prev,
            on_radios_next
        )
    )

    if window and window.monitor_window then
        window.monitor_window.auto_center = true
        gui.load_tab_channels(window.monitor_window, 1)
    end

    return window
end

-- gui.events = {
--     [defines.events.on_lua_shortcut] = on_shortcut,
-- }

flib_gui.add_handlers({
    on_channel_open = on_channel_open,
    on_close_window = on_close_window,
    on_locate_radio_click = on_locate_radio_click,
    on_channels_prev = on_channels_prev,
    on_channels_next = on_channels_next,
    on_radios_prev = on_radios_prev,
    on_radios_next = on_radios_next
})

function gui.gui_dispather(e)
    return flib_gui.dispatch(e)
end

return gui
