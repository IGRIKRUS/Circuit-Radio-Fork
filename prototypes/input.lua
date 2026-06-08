------------------------------------------------------------
-- CIRCUIT RADIO CUSTOM INPUT
------------------------------------------------------------
-- Linked to the normal open-gui control.
-- Required key_sequence is blank because we use the linked game control.

data:extend({
  {
    type = "custom-input",
    name = "circuit-radio-open",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none"
  }
})