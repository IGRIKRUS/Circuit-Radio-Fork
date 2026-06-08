-- Circuit Radio
-- Runtime logic.
-- Current architecture:
--   - One visible Circuit Radio entity for the player
--   - One hidden same-tile bridge per radio
--   - One hidden hub per surface/force/channel
--   - No on-tick signal copying; Factorio's circuit network carries signals


------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------

local RADIO_NAME = "circuit-radio-node"
local BRIDGE_NAME = "circuit-radio-bridge-node"
local HUB_NAME = "circuit-radio-channel-hub"
local OPEN_INPUT = "circuit-radio-open"

local GUI_NAME = "circuit_radio_gui"
local GUI_SIGNAL = "circuit_radio_signal"
local GUI_VALUE = "circuit_radio_value"
local GUI_SAVE = "circuit_radio_save"
local GUI_CANCEL = "circuit_radio_cancel"

local RED_WIRE = defines.wire_connector_id.circuit_red
local GREEN_WIRE = defines.wire_connector_id.circuit_green
local MAX_CHANNEL_VALUE = 2147483647

----------------------------------------------------------
-- RADIO GUI
----------------------------------------------------------

local handler = require("__core__.lualib.event_handler")
local gui_monitor = require('scripts.gui')

handler.add_libraries({ gui_monitor })

local GUI_SWITCH_SURFACE = "circuit_radio_switch_surface"


------------------------------------------------------------
-- STORAGE
------------------------------------------------------------

local function init_storage()
  if type(storage.radios) ~= "table" then storage.radios = {} end
  if type(storage.channels) ~= "table" then storage.channels = {} end
  if type(storage.bridges) ~= "table" then storage.bridges = {} end
  if type(storage.hubs) ~= "table" then storage.hubs = {} end
end


------------------------------------------------------------
-- RENDER HELPERS
------------------------------------------------------------

local function destroy_render_object(object)
  if object and object.valid then
    object.destroy()
  end
end

local function destroy_channel_render(radio)
  if not radio then
    return
  end

  if radio.entity and radio.entity.valid then
    radio.entity.custom_status = nil
  end

  destroy_render_object(radio.channel_sprite_render)
  destroy_render_object(radio.channel_text_render)
  radio.channel_sprite_render = nil
  radio.channel_text_render = nil
  radio.rendered_channel_key = nil
end


------------------------------------------------------------
-- SIGNAL HELPERS
------------------------------------------------------------

local function normalize_signal_id(signal)
  if not (signal and signal.name) then
    return nil
  end

  return {
    type = signal.type or "item",
    name = signal.name,
    quality = signal.quality
  }
end

local function copy_signal(signal)
  local normalized = normalize_signal_id(signal)
  if not normalized then
    return nil
  end

  return {
    type = normalized.type,
    name = normalized.name,
    quality = normalized.quality
  }
end

local function signal_to_text(signal)
  if not signal then
    return "(none)"
  end

  return (signal.type or "item") .. ":" .. signal.name .. ":" .. (signal.quality or "normal")
end

local function sprite_path_for_signal(signal)
  local normalized = normalize_signal_id(signal)
  if not normalized then
    return nil
  end

  if normalized.type == "virtual" then
    return "virtual-signal/" .. normalized.name
  end

  return (normalized.type or "item") .. "/" .. normalized.name
end

local function rich_text_for_signal(signal)
  local normalized = normalize_signal_id(signal)
  if not normalized then
    return "(none)"
  end

  if normalized.type == "virtual" then
    return "[virtual-signal=" .. normalized.name .. "]"
  end

  return "[" .. (normalized.type or "item") .. "=" .. normalized.name .. "]"
end


------------------------------------------------------------
-- CHANNEL HELPERS
------------------------------------------------------------

local function normalize_channel_value(value)
  local number = tonumber(value) or 1

  if number < 1 then
    number = 1
  end

  if number > MAX_CHANNEL_VALUE then
    number = MAX_CHANNEL_VALUE
  end

  return math.floor(number)
end

local function make_channel_key(entity, channel_signal, channel_value, channel_is_global)
  local signal = normalize_signal_id(channel_signal)
  if not (entity and entity.valid and signal) then
    return nil
  end

  local surface = "surface_local:" .. entity.surface.index

  if channel_is_global then
    surface = 'surface_global'
  end

  return surface
      .. "|force:" .. entity.force.index
      .. "|" .. signal_to_text(signal)
      .. ":" .. normalize_channel_value(channel_value)
end

local function channel_to_text(radio)
  if not radio then
    return "(unregistered)"
  end

  local signal = normalize_signal_id(radio.channel_signal)
  if not signal then
    return "(no channel)"
  end

  return signal_to_text(signal) .. ":" .. normalize_channel_value(radio.channel_value)
end

local function channel_to_tags(radio)
  if not (radio and radio.channel_signal) then
    return nil
  end

  return {
    channel_type = radio.channel_signal.type or "item",
    channel_name = radio.channel_signal.name,
    channel_quality = radio.channel_signal.quality,
    channel_value = normalize_channel_value(radio.channel_value)
  }
end

local function tags_to_channel(tags)
  local channel = tags and tags["circuit-radio"]
  if not (channel and channel.channel_name) then
    return nil
  end

  return {
    channel_signal = {
      type = channel.channel_type or "item",
      name = channel.channel_name,
      quality = channel.channel_quality
    },
    channel_value = normalize_channel_value(channel.channel_value)
  }
end

local function apply_channel_tags(radio, tags)
  local channel = tags_to_channel(tags)
  if not channel then
    return
  end

  radio.channel_signal = normalize_signal_id(channel.channel_signal)
  radio.channel_value = normalize_channel_value(channel.channel_value)
end


------------------------------------------------------------
-- COMBINATOR HELPERS
------------------------------------------------------------

local function clear_constant_combinator_sections(entity, enabled)
  if not (entity and entity.valid) then
    return
  end

  local behavior = entity.get_control_behavior()
  if not (behavior and behavior.valid) then
    return
  end

  behavior.enabled = enabled

  for section_index = behavior.sections_count, 1, -1 do
    behavior.remove_section(section_index)
  end
end

local function clear_visible_constant_combinator(entity)
  clear_constant_combinator_sections(entity, true)
end

local function clear_hidden_constant_combinator(entity)
  clear_constant_combinator_sections(entity, false)
end


------------------------------------------------------------
-- HIDDEN ENTITY HELPERS
------------------------------------------------------------

local function register_bridge(radio)
  local bridge = radio and radio.bridge
  if not (bridge and bridge.valid and bridge.unit_number) then
    return
  end

  local radio_unit_number = radio.unit_number
  if not radio_unit_number and radio.entity and radio.entity.valid then
    radio_unit_number = radio.entity.unit_number
  end
  if not radio_unit_number then
    return
  end

  if radio.bridge_registration then
    storage.bridges[radio.bridge_registration] = radio_unit_number
    return
  end

  local registration_number = script.register_on_object_destroyed(bridge)
  storage.bridges[registration_number] = radio_unit_number
  radio.bridge_registration = registration_number
end

local function register_hub(channel, channel_key)
  local hub = channel and channel.hub
  if not (hub and hub.valid and hub.unit_number) then
    return
  end

  if channel.hub_registration then
    storage.hubs[channel.hub_registration] = channel_key
    return
  end

  local registration_number = script.register_on_object_destroyed(hub)
  storage.hubs[registration_number] = channel_key
  channel.hub_registration = registration_number
end

local function create_hidden_entity(surface, force, name, position, direction)
  local entity = surface.create_entity {
    name = name,
    position = position,
    direction = direction or defines.direction.north,
    force = force,
    create_build_effect_smoke = false,
    raise_built = false
  }

  if entity then
    clear_hidden_constant_combinator(entity)
  end

  return entity
end

local function ensure_radio_bridge(radio)
  if not (radio and radio.entity and radio.entity.valid) then
    return nil
  end

  if radio.bridge and radio.bridge.valid then
    radio.bridge.teleport(radio.entity.position)
    radio.bridge.direction = radio.entity.direction
    register_bridge(radio)
    return radio.bridge
  end

  radio.bridge = create_hidden_entity(
    radio.entity.surface,
    radio.entity.force,
    BRIDGE_NAME,
    radio.entity.position,
    radio.entity.direction
  )

  radio.bridge_registration = nil
  register_bridge(radio)
  return radio.bridge
end

local function get_or_create_channel(entity, channel_key)
  if not (entity and entity.valid and channel_key) then
    return nil
  end

  local channel = storage.channels[channel_key]
  if type(channel) == "table" and channel.hub and channel.hub.valid then
    if type(channel.radios) ~= "table" then
      channel.radios = {}
    end

    register_hub(channel, channel_key)
    return channel
  end

  if channel ~= nil then
    storage.channels[channel_key] = nil
  end

  local hub = create_hidden_entity(
    entity.surface,
    entity.force,
    HUB_NAME,
    { 0, 0 },
    defines.direction.north
  )

  if not hub then
    return nil
  end

  channel = {
    hub = hub,
    radios = {}
  }

  storage.channels[channel_key] = channel
  register_hub(channel, channel_key)
  return channel
end

local function destroy_hidden_entity(entity)
  if entity and entity.valid then
    entity.destroy()
  end
end


------------------------------------------------------------
-- WIRE HELPERS
------------------------------------------------------------

local function disconnect_connector_from_owner(connector, owner_name)
  if not connector then
    return
  end

  for _, connection in pairs(connector.connections) do
    local owner = connection.target and connection.target.owner
    if owner and owner.valid and owner.name == owner_name then
      connector.disconnect_from(connection.target, defines.wire_origin.script)
    end
  end
end

local function disconnect_bridge_from_hubs(bridge)
  if not (bridge and bridge.valid) then
    return
  end

  disconnect_connector_from_owner(bridge.get_wire_connector(RED_WIRE, true), HUB_NAME)
  disconnect_connector_from_owner(bridge.get_wire_connector(GREEN_WIRE, true), HUB_NAME)
end

local function connect_wire(source, target, wire)
  if not (source and source.valid and target and target.valid) then
    return
  end

  local source_connector = source.get_wire_connector(wire, true)
  local target_connector = target.get_wire_connector(wire, true)

  if source_connector and target_connector then
    source_connector.connect_to(target_connector, false, defines.wire_origin.script)
  end
end

local function connect_radio_to_bridge(radio)
  local bridge = ensure_radio_bridge(radio)
  if not bridge then
    return
  end

  if not (radio.entity and radio.entity.valid) then
    return
  end

  connect_wire(radio.entity, bridge, RED_WIRE)
  connect_wire(radio.entity, bridge, GREEN_WIRE)
end


------------------------------------------------------------
-- CHANNEL WIRING
------------------------------------------------------------

local function cleanup_empty_channel(channel_key)
  local channel = channel_key and storage.channels[channel_key]
  if not channel then
    return
  end

  if type(channel) ~= "table" then
    storage.channels[channel_key] = nil
    return
  end

  if type(channel.radios) ~= "table" then
    channel.radios = {}
  end

  for unit_number in pairs(channel.radios or {}) do
    local radio = storage.radios[unit_number]
    if type(radio) == "table" and radio.entity and radio.entity.valid and radio.channel_key == channel_key then
      return
    end

    channel.radios[unit_number] = nil
  end

  destroy_hidden_entity(channel.hub)
  storage.channels[channel_key] = nil
end

local function disconnect_radio_from_channel(radio)
  if not radio then
    return
  end

  local old_key = radio.channel_key
  local unit_number = radio.unit_number
  if not unit_number and radio.entity and radio.entity.valid then
    unit_number = radio.entity.unit_number
  end

  if radio.bridge and radio.bridge.valid then
    disconnect_bridge_from_hubs(radio.bridge)
  end

  local old_channel = old_key and storage.channels[old_key]
  if type(old_channel) == "table" then
    if unit_number then
      if type(old_channel.radios) ~= "table" then
        old_channel.radios = {}
      end

      old_channel.radios[unit_number] = nil
    end

    cleanup_empty_channel(old_key)
  end

  radio.channel_key = nil
end

local function connect_radio_to_channel(radio, channel_key)
  if not (radio and radio.entity and radio.entity.valid and channel_key) then
    return
  end

  local bridge = ensure_radio_bridge(radio)
  local channel = get_or_create_channel(radio.entity, channel_key)

  if not (bridge and type(channel) == "table" and channel.hub and channel.hub.valid) then
    return
  end

  if type(channel.radios) ~= "table" then
    channel.radios = {}
  end

  connect_radio_to_bridge(radio)
  connect_wire(bridge, channel.hub, RED_WIRE)
  connect_wire(bridge, channel.hub, GREEN_WIRE)

  radio.unit_number = radio.unit_number or radio.entity.unit_number
  channel.radios[radio.unit_number] = true
  radio.channel_key = channel_key
end


------------------------------------------------------------
-- RADIO REGISTRATION
------------------------------------------------------------

local function update_channel_render(radio)
  if not (radio and radio.entity and radio.entity.valid) then
    destroy_channel_render(radio)
    return
  end

  local channel_key = make_channel_key(radio.entity, radio.channel_signal, radio.channel_value, radio.channel_is_global)
  if not channel_key then
    radio.entity.custom_status = nil
    destroy_channel_render(radio)
    return
  end

  radio.entity.custom_status = {
    diode = defines.entity_status_diode.green,
    label = {
      "",
      "Channel: ",
      rich_text_for_signal(radio.channel_signal),
      " ",
      tostring(normalize_channel_value(radio.channel_value))
    }
  }

  if radio.rendered_channel_key == channel_key
      and radio.channel_sprite_render
      and radio.channel_sprite_render.valid
      and radio.channel_text_render
      and radio.channel_text_render.valid then
    return
  end

  destroy_channel_render(radio)

  local sprite = sprite_path_for_signal(radio.channel_signal)
  if not sprite then
    return
  end

  radio.channel_sprite_render = rendering.draw_sprite {
    sprite = sprite,
    surface = radio.entity.surface,
    target = {
      entity = radio.entity,
      offset = { -0.13, 0 }
    },
    x_scale = 0.42,
    y_scale = 0.42,
    render_layer = "entity-info-icon",
    only_in_alt_mode = true
  }

  radio.channel_text_render = rendering.draw_text {
    text = tostring(normalize_channel_value(radio.channel_value)),
    surface = radio.entity.surface,
    target = {
      entity = radio.entity,
      offset = { 0.07, -0.01 }
    },
    color = { r = 1, g = 1, b = 1 },
    scale = 0.85,
    font = "default-bold",
    alignment = "left",
    vertical_alignment = "middle",
    only_in_alt_mode = true
  }

  radio.rendered_channel_key = channel_key
end

local function refresh_radio_connections(radio)
  if not (radio and radio.entity and radio.entity.valid) then
    return
  end

  clear_visible_constant_combinator(radio.entity)
  connect_radio_to_bridge(radio)
  update_channel_render(radio)

  local new_key = make_channel_key(radio.entity, radio.channel_signal, radio.channel_value, radio.channel_is_global)
  if radio.channel_key == new_key then
    return
  end

  disconnect_radio_from_channel(radio)

  if new_key then
    connect_radio_to_channel(radio, new_key)
  end
end

local function register_radio(entity, tags)
  if not (entity and entity.valid and entity.name == RADIO_NAME and entity.unit_number) then
    return nil
  end

  init_storage()

  local unit_number = entity.unit_number
  local radio = storage.radios[unit_number] or {}

  radio.entity = entity
  radio.unit_number = unit_number
  radio.channel_signal = normalize_signal_id(radio.channel_signal)
  radio.channel_value = normalize_channel_value(radio.channel_value)

  apply_channel_tags(radio, tags)

  storage.radios[unit_number] = radio
  refresh_radio_connections(radio)

  return radio
end

local function unregister_radio(entity)
  if not (entity and entity.valid and entity.name == RADIO_NAME and entity.unit_number) then
    return
  end

  init_storage()

  local radio = storage.radios[entity.unit_number]
  if radio then
    disconnect_radio_from_channel(radio)
    destroy_channel_render(radio)
    destroy_hidden_entity(radio.bridge)
  end

  storage.radios[entity.unit_number] = nil
end

local function cleanup_radios()
  init_storage()

  local count = 0

  for unit_number, radio in pairs(storage.radios) do
    if type(radio) == "table" and radio.entity and radio.entity.valid and radio.entity.name == RADIO_NAME then
      radio.unit_number = radio.unit_number or unit_number
      refresh_radio_connections(radio)
      count = count + 1
    else
      if type(radio) == "table" then
        radio.unit_number = radio.unit_number or unit_number
        disconnect_radio_from_channel(radio)
        destroy_channel_render(radio)
        destroy_hidden_entity(radio.bridge)
      end

      storage.radios[unit_number] = nil
    end
  end

  for channel_key in pairs(storage.channels) do
    cleanup_empty_channel(channel_key)
  end

  return count
end

local function cleanup_orphan_hidden_entities()
  init_storage()

  local valid_bridges = {}
  local valid_hubs = {}

  for _, radio in pairs(storage.radios) do
    if type(radio) ~= "table" then goto continue_radio end

    if radio.bridge and radio.bridge.valid then
      valid_bridges[radio.bridge.unit_number] = true
    end

    ::continue_radio::
  end

  for _, channel in pairs(storage.channels) do
    if type(channel) ~= "table" then goto continue_channel end

    if channel.hub and channel.hub.valid then
      valid_hubs[channel.hub.unit_number] = true
    end

    ::continue_channel::
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered { name = BRIDGE_NAME }) do
      if entity.unit_number and not valid_bridges[entity.unit_number] then
        entity.destroy()
      end
    end

    for _, entity in pairs(surface.find_entities_filtered { name = HUB_NAME }) do
      if entity.unit_number and not valid_hubs[entity.unit_number] then
        entity.destroy()
      end
    end
  end
end


------------------------------------------------------------
-- GUI HELPERS
------------------------------------------------------------

local function destroy_radio_gui(player)
  if player and player.valid and player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  end
end

local function find_child_by_name(parent, name)
  if not parent then
    return nil
  end

  for _, child in pairs(parent.children) do
    if child.name == name then
      return child
    end

    local found = find_child_by_name(child, name)
    if found then
      return found
    end
  end

  return nil
end

local function find_gui_frame(element)
  local current = element

  while current do
    if current.name == GUI_NAME then
      return current
    end

    current = current.parent
  end

  return nil
end

local function open_radio_gui(player, entity)
  if not (player and player.valid and entity and entity.valid and entity.name == RADIO_NAME) then
    return
  end

  local radio = register_radio(entity)
  if not radio then
    return
  end

  destroy_radio_gui(player)

  local frame = player.gui.screen.add {
    type = "frame",
    name = GUI_NAME,
    caption = "Circuit Radio",
    direction = "vertical"
  }

  frame.auto_center = true
  frame.tags = {
    unit_number = entity.unit_number
  }

  frame.add {
    type = "label",
    caption = { "radio-interface.combinator-channel-signal" }
  }

  local signal_button = frame.add {
    type = "choose-elem-button",
    name = GUI_SIGNAL,
    elem_type = "signal"
  }

  if radio.channel_signal then
    signal_button.elem_value = radio.channel_signal
  end

  frame.add {
    type = "label",
    caption = { "radio-interface.combinator-channel-number" }
  }

  frame.add {
    type = "textfield",
    name = GUI_VALUE,
    text = tostring(radio.channel_value or 1),
    numeric = true,
    allow_decimal = false,
    allow_negative = false
  }

  local switch_flow = frame.add {
    type = "flow",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  }

  switch_flow.style.vertical_align = "center"

  switch_flow.add {
    type = "label",
    caption = { "radio-interface.combinator-switch-local" }
  }

  local switch_state = "left"
  if radio.channel_is_global == true then
    switch_state = "right"
  end

  switch_flow.add {
    type = "switch",
    name = GUI_SWITCH_SURFACE,
    switch_state = switch_state,
    allow_none_state = false
  }

  switch_flow.add {
    type = "label",
    caption = { "radio-interface.combinator-switch-global" }
  }

  local button_flow = frame.add {
    type = "flow",
    name = "circuit_radio_button_flow",
    direction = "horizontal"
  }

  button_flow.add {
    type = "button",
    name = GUI_SAVE,
    caption = { "radio-interface.combinator-button-save" }
  }

  button_flow.add {
    type = "button",
    name = GUI_CANCEL,
    caption = { "radio-interface.combinator-button-cancel" }
  }

  player.opened = frame
end

local function save_radio_gui(player, frame)
  if not (player and player.valid and frame and frame.valid) then
    return
  end

  init_storage()

  local unit_number = frame.tags and frame.tags.unit_number
  if not unit_number then
    destroy_radio_gui(player)
    return
  end

  local radio = storage.radios[unit_number]
  if not (radio and radio.entity and radio.entity.valid) then
    destroy_radio_gui(player)
    return
  end

  local signal_button = find_child_by_name(frame, GUI_SIGNAL)
  local value_field = find_child_by_name(frame, GUI_VALUE)
  local switch_surface = find_child_by_name(frame, GUI_SWITCH_SURFACE)

  if not (signal_button and signal_button.valid and value_field and value_field.valid and switch_surface and switch_surface.valid) then
    destroy_radio_gui(player)
    return
  end

  radio.channel_signal = normalize_signal_id(signal_button.elem_value)
  radio.channel_value = normalize_channel_value(value_field.text)

  if switch_surface.switch_state == "right" then
    radio.channel_is_global = true;
  else
    radio.channel_is_global = false
  end

  refresh_radio_connections(radio)

  destroy_radio_gui(player)
end


------------------------------------------------------------
-- EVENT HELPERS
------------------------------------------------------------

local function get_player(event)
  if not event.player_index then
    return nil
  end

  return game.get_player(event.player_index)
end

local function player_is_holding_tool(player)
  local cursor_stack = player.cursor_stack
  if not (cursor_stack and cursor_stack.valid_for_read) then
    return false
  end

  local tools = {
    ["red-wire"] = true,
    ["green-wire"] = true,
    ["copy-paste-tool"] = true,
    ["cut-paste-tool"] = true,
    ["blueprint"] = true,
    ["blueprint-book"] = true,
    ["deconstruction-planner"] = true,
    ["upgrade-planner"] = true,
    ["selection-tool"] = true
  }

  return tools[cursor_stack.name] == true
end


------------------------------------------------------------
-- INIT EVENTS
------------------------------------------------------------

script.on_init(function()
  init_storage()
end)

script.on_configuration_changed(function()
  init_storage()
  cleanup_radios()
  cleanup_orphan_hidden_entities()
end)

------------------------------------------------------------
-- BUILD / REMOVE EVENTS
------------------------------------------------------------

script.on_event(defines.events.on_built_entity, function(event)
  register_radio(event.entity, event.tags)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
  register_radio(event.entity, event.tags)
end)

script.on_event(defines.events.on_space_platform_built_entity, function(event)
  register_radio(event.entity, event.tags)
end)

script.on_event(defines.events.script_raised_built, function(event)
  register_radio(event.entity)
end)

script.on_event(defines.events.script_raised_revive, function(event)
  register_radio(event.entity)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
  unregister_radio(event.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
  unregister_radio(event.entity)
end)

script.on_event(defines.events.on_entity_died, function(event)
  unregister_radio(event.entity)
end)

script.on_event(defines.events.script_raised_destroy, function(event)
  unregister_radio(event.entity)
end)

script.on_event(defines.events.on_entity_cloned, function(event)
  if not (event.source and event.source.valid and event.source.name == RADIO_NAME) then
    return
  end

  if not (event.destination and event.destination.valid and event.destination.name == RADIO_NAME) then
    return
  end

  local source_radio = register_radio(event.source)
  register_radio(event.destination, {
    ["circuit-radio"] = channel_to_tags(source_radio)
  })
end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
  if event.entity and event.entity.valid and event.entity.name == RADIO_NAME then
    register_radio(event.entity)
  end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  if not (event.source and event.source.valid and event.source.name == RADIO_NAME) then
    return
  end

  if not (event.destination and event.destination.valid and event.destination.name == RADIO_NAME) then
    return
  end

  local source_radio = register_radio(event.source)
  local destination_radio = register_radio(event.destination)

  if not (source_radio and destination_radio) then
    return
  end

  destination_radio.channel_signal = copy_signal(source_radio.channel_signal)
  destination_radio.channel_value = source_radio.channel_value
  refresh_radio_connections(destination_radio)
end)

script.on_event(defines.events.on_object_destroyed, function(event)
  init_storage()

  local radio_unit_number = storage.bridges[event.registration_number]
  if radio_unit_number then
    storage.bridges[event.registration_number] = nil

    local radio = storage.radios[radio_unit_number]
    if radio then
      radio.bridge = nil
      refresh_radio_connections(radio)
    end

    return
  end

  local channel_key = storage.hubs[event.registration_number]
  if channel_key then
    storage.hubs[event.registration_number] = nil

    local channel = storage.channels[channel_key]
    storage.channels[channel_key] = nil

    local channel_radios = type(channel) == "table" and type(channel.radios) == "table" and channel.radios or {}

    for unit_number in pairs(channel_radios) do
      local radio = storage.radios[unit_number]
      if radio then
        radio.channel_key = nil
        refresh_radio_connections(radio)
      end
    end
  end
end)

local function get_setup_blueprint(event)
  if event.stack then
    local stack = event.stack
    if stack.valid == false or stack.valid_for_read == false then
      return nil
    end

    if stack.is_blueprint_setup and stack.is_blueprint_setup() then
      return stack
    end

    return nil
  end

  local record = event.record
  if not (record and record.valid and record.type == "blueprint") then
    return nil
  end

  if record.valid_for_write == false then
    return nil
  end

  if record.is_blueprint_setup and record.is_blueprint_setup() then
    return record
  end

  return nil
end

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local blueprint = get_setup_blueprint(event)
  if not blueprint then
    return
  end

  local mapping = event.mapping and event.mapping.valid and event.mapping.get()
  if not mapping then
    return
  end

  for blueprint_index, source_entity in pairs(mapping) do
    if source_entity and source_entity.valid and source_entity.name == RADIO_NAME then
      local radio = register_radio(source_entity)
      local tags = blueprint.get_blueprint_entity_tags(blueprint_index) or {}
      tags["circuit-radio"] = channel_to_tags(radio)

      blueprint.set_blueprint_entity_tags(blueprint_index, tags)
    end
  end
end)


------------------------------------------------------------
-- GUI OPEN EVENT
------------------------------------------------------------

script.on_event(defines.events.on_gui_opened, function(event)
  if not (event.entity and event.entity.valid and event.entity.name == RADIO_NAME) then
    return
  end

  local player = get_player(event)
  if not player then
    return
  end

  if player_is_holding_tool(player) then
    return
  end

  player.opened = nil
  open_radio_gui(player, event.entity)
end)

script.on_event(OPEN_INPUT, function(event)
  local player = get_player(event)
  if not player then
    return
  end

  if player_is_holding_tool(player) then
    return
  end

  local selected = player.selected
  if selected and selected.valid and selected.name == RADIO_NAME then
    open_radio_gui(player, selected)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  gui_monitor.on_shortcut(event)
end)

------------------------------------------------------------
-- GUI CLOSE EVENT
------------------------------------------------------------

script.on_event(defines.events.on_gui_closed, function(event)
  local player = get_player(event)
  if not player then
    return
  end

  if event.element and event.element.valid and event.element.name == GUI_NAME then
    destroy_radio_gui(player)
  end
end)

------------------------------------------------------------
-- GUI CLICK EVENT
------------------------------------------------------------

script.on_event(defines.events.on_gui_click, function(event)
  if gui_monitor.gui_dispather(event) then
    return
  end

  local element = event.element

  if not (element and element.valid) then
    return
  end

  if element.name ~= GUI_SAVE and element.name ~= GUI_CANCEL then
    return
  end

  local player = get_player(event)
  if not player then
    return
  end

  local frame = find_gui_frame(element)

  if element.name == GUI_CANCEL then
    destroy_radio_gui(player)
    return
  end

  save_radio_gui(player, frame)
end)


------------------------------------------------------------
-- DEBUG COMMANDS
------------------------------------------------------------

commands.add_command("circuit-radio-count", "Counts registered Circuit Radio nodes.", function()
  local count = cleanup_radios()
  game.print("Circuit Radio nodes registered: " .. count)
end)

commands.add_command("circuit-radio-info", "Prints the selected Circuit Radio channel.", function(command)
  init_storage()

  local player = command.player_index and game.get_player(command.player_index)
  if not player then
    game.print("Run this command as a player with a Circuit Radio selected.")
    return
  end

  local selected = player.selected
  if not (selected and selected.valid and selected.name == RADIO_NAME) then
    player.print("Select a Circuit Radio first.")
    return
  end

  local radio = register_radio(selected)
  player.print("Circuit Radio unit " .. selected.unit_number .. " channel: " .. channel_to_text(radio))
end)
