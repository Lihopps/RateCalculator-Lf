data:extend({
  {
    type = "int-setting",
    name = "rcalc-entities-per-tick",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 1,
    maximum_value = 50,
  },
  {
    type = "bool-setting",
    name = "rcalc-dismiss-tool-on-selection",
    setting_type = "runtime-per-user",
    default_value = false,
  },
})
