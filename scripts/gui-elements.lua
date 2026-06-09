---@type flib_gui
local flib_gui = require("__flib__.gui")

local gui_elements = {}

function gui_elements.parse_channel_key(key_string)
    local scope, force, sig_type, sig_name, quality, value = string.match(key_string,
        "([^|]+)|force:(%d+)|([^:]+):([^:]+):([^:]+):(%d+)")
    local channel_number = tonumber(value)

    local scope_sprite = "item/radar"

    if scope == "surface_global" then
        scope_sprite = "space-location/solar-system-edge"
    end

    local signal_sprite = nil

    if sig_type and sig_name then
        if sig_type == "virtual" then
            signal_sprite = "virtual-signal/" .. sig_name
        else
            signal_sprite = sig_type .. "/" .. sig_name
        end
    end

    return scope_sprite, signal_sprite, channel_number
end

function gui_elements.get_surface_name_and_sprite(surface)
    local surface_sprite = "virtual-signal/signal-unknown"

    if prototypes.space_location[surface.name] then
        surface_sprite = "space-location/" .. surface.name
    end

    local surface_name = { "?", { "space-location-name." .. surface.name }, surface.name }

    if surface.platform then
        surface_sprite = "item/space-platform-hub"
        surface_name = surface.platform.name
    end

    return surface_name, surface_sprite
end

function gui_elements.no_channels()
    return {
        type = "flow",
        direction = "horizontal",
        style = "horizontal_flow",
        style_mods = {
            top_margin = 6,
            bottom_margin = 6,
            left_margin = 6
        },
        { type = "label", caption = { "radio-interface.msg-no-channels" } }
    }
end

function gui_elements.no_radios()
    return {
        type = "flow",
        direction = "horizontal",
        style = "horizontal_flow",
        style_mods = {
            top_margin = 6,
            bottom_margin = 6,
            left_margin = 6
        },
        { type = "label", caption = { "radio-interface.msg-no-stations" } }
    }
end

function gui_elements.channels_head()
    return {
        type = "table",
        column_count = 5,
        style = "bordered_table",
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 50,
            { type = "label", style = "bold_label", caption = { "radio-interface.col-scope" } },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 50,
            { type = "label", style = "bold_label", caption = { "radio-interface.col-signal" } },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 80,
            { type = "label", style = "bold_label", caption = { "radio-interface.col-id" } },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 50,
            { type = "label", style = "bold_label", caption = { "radio-interface.col-count" } },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 55,
            { type = "label", style = "bold_label", caption = { "radio-interface.col-open" } },
        },
    }
end

function gui_elements.channels_row(
    channel_table,
    channel_key,
    radios_count,
    is_selected,
    channel_click_fn
)
    local scope, signal, channel_number = gui_elements.parse_channel_key(channel_key)

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        {
            type = "sprite",
            sprite = scope,
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        {
            type = "sprite",
            sprite = signal,
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 80,
        vertical_align = "center",
        {
            type = "label",
            style = "bold_label",
            caption = "#" .. channel_number,
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        vertical_align = "center",
        {
            type = "label",
            caption = radios_count,
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 55,
        vertical_align = "center",
        horizontal_align = "center",
        {
            type = "sprite-button",
            style = is_selected and "flib_selected_tool_button" or "tool_button",
            sprite = "utility/forward_arrow",
            tags = {
                channel_id = channel_key,
                is_active = is_selected
            },
            handler = { [defines.events.on_gui_click] = channel_click_fn },
        },
    })
end

function gui_elements.channels_deleted_row(channel_table)
    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        {
            type = "sprite",
            sprite = "virtual-signal/signal-trash-bin",
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        {
            type = "sprite",
            sprite = "virtual-signal/signal-unknown",
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 80,
        vertical_align = "center",
        {
            type = "label",
            style = "bold_label",
            caption = "Deleted",
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 50,
        vertical_align = "center",
        {
            type = "label",
            caption = 0,
        },
    })

    table.insert(channel_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 55,
        vertical_align = "center",
        horizontal_align = "center"
    })
end

function gui_elements.radios_head()
    return {
        type = "table",
        column_count = 3,
        style = "bordered_table",
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 80,
            {
                type = "label",
                style = "bold_label",
                caption = { 'radio-interface.col-radio-id' }
            },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 150,
            {
                type = "label",
                style = "bold_label",
                caption = { 'radio-interface.col-surface' }
            },
        },
        {
            type = "flow",
            direction = "horizontal",
            minimal_width = 60,
            {
                type = "label",
                style = "bold_label",
                caption = { 'radio-interface.col-locate' }
            },
        },
    }
end

function gui_elements.radios_row(
    radios_table,
    radio_id,
    surface_sprite,
    surface_name,
    radio_click_fn
)
    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 80,
        vertical_align = "center",
        { type = "label", caption = "#" .. radio_id },
    })

    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 150,
        vertical_align = "center",
        horizontal_align = "center",
        { type = "sprite", sprite = surface_sprite },
        {
            type = "flow",
            direction = "horizontal",
            vertical_align = "center",
            style_mods = { top_margin = 10, left_margin = 2 },
            { type = "label", caption = surface_name },
        },
    })

    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 60,
        vertical_align = "center",
        {
            type = "sprite-button",
            style = "tool_button",
            sprite = "utility/search",
            tags = { radio_id = radio_id },
            handler = { [defines.events.on_gui_click] = radio_click_fn },
        },
    })
end

function gui_elements.radios_deleted_row(radios_table)
    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 80,
        vertical_align = "center",
        { type = "label", caption = "#destroyed" },
    })

    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 150,
        vertical_align = "center",
        horizontal_align = "center",
        { type = "sprite", sprite = "virtual-signal/signal-unknown" },
        {
            type = "flow",
            direction = "horizontal",
            vertical_align = "center",
            style_mods = { top_margin = 10, left_margin = 2 },
            { type = "label", caption = "destroyed" },
        },
    })

    table.insert(radios_table, {
        type = "flow",
        direction = "horizontal",
        minimal_width = 60,
        vertical_align = "center",
    })
end

function gui_elements.pagination_footer(prefix, prev_fn, next_fn)
    return {
        type = "flow",
        name = prefix .. "_pagination_flow",
        direction = "horizontal",
        style = "horizontal_flow",
        vertical_align = "center",
        visible = false,
        tags = {
            page_history = {}
        },
        style_mods = {
            top_margin = 6,
            bottom_margin = 6,
            left_margin = 6
        },
        {
            type = "sprite-button",
            style = "tool_button",
            sprite = "utility/left_arrow",
            handler = { [defines.events.on_gui_click] = prev_fn },
        },
        {
            type = "label",
            name = "page_label",
            style = "bold_label",
            caption = " 1 / 1 ",
        },
        {
            type = "sprite-button",
            style = "tool_button",
            sprite = "utility/right_arrow",
            handler = { [defines.events.on_gui_click] = next_fn },
        },
    }
end

function gui_elements.channels_frame(channels_prev_page_fn, channels_next_page_fn)
    return {
        type = "frame",
        name = "left_block_frame",
        direction = "vertical",
        style = "inside_shallow_frame",
        {
            type = "flow",
            direction = "vertical",
            style_mods = {
                top_margin = 6,
                bottom_margin = 6,
                left_margin = 6,
                minimal_width = 140,
            },
            {
                type = "label",
                style = "heading_2_label",
                caption = { "radio-interface.tab-channels" }
            },
        },
        {
            type = "scroll-pane",
            name = "channels_scroll_zone",
            style = "scroll_pane",
            minimal_width = 450,
            maximal_height = 450,
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto",
        },
        gui_elements.pagination_footer("channels", channels_prev_page_fn, channels_next_page_fn),
    }
end

function gui_elements.radios_frame(radios_prev_page_fn, radios_next_page_fn)
    return {
        type = "frame",
        name = "right_block_frame",
        direction = "vertical",
        style = "inside_shallow_frame",
        {
            type = "flow",
            direction = "vertical",
            style_mods = {
                top_margin = 6,
                bottom_margin = 6,
                left_margin = 6,
                minimal_width = 240,
            },
            {
                type = "label",
                style = "heading_2_label",
                caption = { "radio-interface.tab-stations" }
            },
        },
        {
            type = "scroll-pane",
            name = "radios_scroll_zone",
            style = "scroll_pane",
            minimal_width = 450,
            maximal_height = 450,
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto",
            {
                type = "flow",
                direction = "vertical",
                style_mods = {
                    top_margin = 6,
                    bottom_margin = 6,
                    left_margin = 6
                },
                {
                    type = "label",
                    caption = { "radio-interface.msg-select-channel" }
                },
            },
        },
        gui_elements.pagination_footer("radios", radios_prev_page_fn, radios_next_page_fn),
    }
end

function gui_elements.window(
    window_close_fn,
    channels_prev_page_fn,
    channels_next_page_fn,
    radios_prev_page_fn,
    radios_next_page_fn
)
    return {
        type = "frame",
        name = "monitor_window",
        direction = "vertical",
        tags = {
            channels_page = 1,
            radios_page = 1,
            current_channel = nil,
        },
        handler = { [defines.events.on_gui_closed] = window_close_fn },
        {
            type = "flow",
            direction = "horizontal",
            style = "flib_titlebar_flow",
            {
                type = "label",
                style = "frame_title",
                caption = { "radio-interface.window-title" },
                ignored_by_interaction = true,
            },
            {
                type = "empty-widget",
                style = "flib_titlebar_drag_handle",
                drag_target = "monitor_window",
            },
            {
                type = "sprite-button",
                style = "frame_action_button",
                sprite = "utility/close",
                handler = { [defines.events.on_gui_click] = window_close_fn },
            },
        },
        {
            type = "flow",
            name = "horizontal_container",
            direction = "horizontal",
            style = "horizontal_flow",
            gui_elements.channels_frame(channels_prev_page_fn, channels_next_page_fn),
            {
                type = "empty-widget",
                minimal_width = 12
            },
            gui_elements.radios_frame(radios_prev_page_fn, radios_next_page_fn)
        },
    }
end

function gui_elements.get_window(player)
    if player and player.gui.screen.monitor_window then
        return player.gui.screen.monitor_window
    end
end

function gui_elements.get_channels_scroll_zone(window)
    return window.horizontal_container.left_block_frame.channels_scroll_zone
end

function gui_elements.get_channels_pagination_flow(window)
    return window.horizontal_container.left_block_frame.channels_pagination_flow
end

function gui_elements.get_radios_scroll_zone(window)
    return window.horizontal_container.right_block_frame.radios_scroll_zone
end

function gui_elements.get_radios_pagination_flow(window)
    return window.horizontal_container.right_block_frame.radios_pagination_flow
end

return gui_elements
