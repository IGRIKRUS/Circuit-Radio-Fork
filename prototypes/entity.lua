------------------------------------------------------------
-- CIRCUIT RADIO ENTITY
------------------------------------------------------------
-- The visible radio is a real constant-combinator prototype. This keeps
-- Factorio's polished 1x1 combinator graphics, rotation, circuit wire
-- connector positions, and red/green wire interaction.
--
-- Runtime code owns the GUI and clears the native constant-combinator
-- signal slots so the channel selector cannot leak onto the circuit network.

local radio = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local bridge = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local hub = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local remnants = table.deepcopy(data.raw["corpse"]["constant-combinator-remnants"])
local empty_sprite = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1
}

local function use_local_graphics(value)
  if type(value) ~= "table" then
    return
  end

  for key, child in pairs(value) do
    if key == "filename" and type(child) == "string" then
      child = child:gsub(
        "__base__/graphics/entity/combinator/",
        "__circuit-radio__/graphics/entity/combinator/"
      )
      value[key] = child
    elseif type(child) == "table" then
      use_local_graphics(child)
    end
  end
end

local function use_taller_radio_sprite(value)
  if type(value) ~= "table" then
    return
  end

  if value.filename == "__circuit-radio__/graphics/entity/combinator/constant-combinator.png" then
    value.height = 125
    value.shift = util.by_pixel(0, -0.75)
  end

  for _, child in pairs(value) do
    if type(child) == "table" then
      use_taller_radio_sprite(child)
    end
  end
end

radio.name = "circuit-radio-node"
radio.localised_name = {"entity-name.circuit-radio-node"}
radio.localised_description = {"entity-description.circuit-radio-node"}

radio.icon = "__circuit-radio__/graphics/icons/circuit-radio-node.png"
radio.icon_size = 64
radio.minable = {
  mining_time = 0.1,
  result = "circuit-radio-node"
}

radio.fast_replaceable_group = "circuit-radio-node"
radio.next_upgrade = nil
radio.corpse = "circuit-radio-node-remnants"
use_local_graphics(radio)
use_taller_radio_sprite(radio)

remnants.name = "circuit-radio-node-remnants"
remnants.localised_name = {"entity-name.circuit-radio-node"}
use_local_graphics(remnants)

bridge.name = "circuit-radio-bridge-node"
bridge.localised_name = {"entity-name.circuit-radio-node"}
bridge.localised_description = {"entity-description.circuit-radio-node"}
bridge.hidden = true
bridge.hidden_in_factoriopedia = true
bridge.flags = {
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-flammable",
  "hide-alt-info"
}
bridge.minable = nil
bridge.collision_box = {{0, 0}, {0, 0}}
bridge.collision_mask = {layers = {}}
bridge.selection_box = {{0, 0}, {0, 0}}
bridge.selectable_in_game = false
bridge.allow_copy_paste = false
bridge.corpse = nil
bridge.dying_explosion = nil
bridge.sprites = empty_sprite
bridge.activity_led_sprites = empty_sprite
bridge.activity_led_light = nil
bridge.draw_circuit_wires = false
bridge.draw_copper_wires = false

hub.name = "circuit-radio-channel-hub"
hub.localised_name = {"entity-name.circuit-radio-node"}
hub.localised_description = {"entity-description.circuit-radio-node"}
hub.hidden = true
hub.hidden_in_factoriopedia = true
hub.flags = {
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-flammable",
  "hide-alt-info",
  "placeable-off-grid"
}
hub.minable = nil
hub.collision_box = {{0, 0}, {0, 0}}
hub.collision_mask = {layers = {}}
hub.selection_box = {{0, 0}, {0, 0}}
hub.selectable_in_game = false
hub.allow_copy_paste = false
hub.corpse = nil
hub.dying_explosion = nil
hub.sprites = empty_sprite
hub.activity_led_sprites = empty_sprite
hub.activity_led_light = nil
hub.draw_circuit_wires = false
hub.draw_copper_wires = false
hub.circuit_wire_max_distance = 2000000

data:extend({radio, bridge, hub, remnants})
