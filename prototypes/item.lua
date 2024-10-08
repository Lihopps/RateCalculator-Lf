local data_util = require("__flib__.data-util")

local type_filters = {
  "accumulator",
  "ammo-turret",
  "arithmetic-combinator",
  "artillery-turret",
  "assembling-machine",
  "beacon",
  "boiler",
  "burner-generator",
  "constant-combinator",
  "decider-combinator",
  "electric-energy-interface",
  "electric-turret",
  "fluid-turret",
  "furnace",
  "generator",
  "heat-interface",
  "inserter",
  "lab",
  "lamp",
  "loader",
  "loader-1x1",
  "locomotive",
  "mining-drill",
  "offshore-pump",
  "programmable-speaker",
  "pump",
  "radar",
  "reactor",
  "roboport",
  "rocket-silo",
  "solar-panel",
  "turret",
}

data:extend({
  {
    type = "selection-tool",
    name = "rcalc-selection-tool",
    order = "d[tools]-r[rate-calculator]",
    icons = {
      { icon = data_util.black_image, icon_size = 1, scale = 64 },
      { icon = "__RateCalculator-Lf__/graphics/shortcut-x32-white.png", icon_size = 32, mipmap_count = 2 },
    },

    selection_color = { r = 1, g = 1 },
    selection_cursor_box_type = "entity",
    selection_mode = { "buildable-type", "friend" },
    entity_type_filters = type_filters,

    alt_selection_color = { r = 1, g = 0.5 },
    alt_selection_cursor_box_type = "entity",
    alt_selection_mode = { "buildable-type", "friend" },
    alt_entity_type_filters = type_filters,

    reverse_selection_color = { a = 0 },
    reverse_selection_mode = { "nothing" },

    alt_reverse_selection_color = { r = 1 },
    alt_reverse_selection_cursor_box_type = "not-allowed",
    alt_reverse_selection_mode = { "buildable-type", "friend" },
    alt_reverse_entity_type_filters = type_filters,

    stack_size = 1,
    flags = { "hidden", "only-in-cursor", "not-stackable", "spawnable" },
  },
  {
    type = "item",
    name = "rcalc-power-dummy",
    icon = "__RateCalculator-Lf__/graphics/power.png",
    icon_size = 64,
    stack_size = 1,
    flags = { "hidden" },
  },
  {
    type = "item",
    name = "rcalc-heat-dummy",
    icon = "__core__/graphics/arrows/heat-exchange-indication.png",
    icon_size = 48,
    stack_size = 1,
    flags = { "hidden" },
  },
  {
    type = "item",
    name = "rcalc-pollution-dummy",
    icon = "__RateCalculator-Lf__/graphics/pollution.png",
    icon_size = 64,
    icon_mipmaps = 2,
    stack_size = 1,
    flags = { "hidden" },
  },
})
