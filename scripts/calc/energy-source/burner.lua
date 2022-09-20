local calc_util = require("scripts.calc.util")

--- @param entity LuaEntity
--- @param emissions_per_second number
--- @return number
return function(rates, entity, emissions_per_second)
  local entity_prototype = entity.prototype
  local burner_prototype = entity_prototype.burner_prototype

  local burner = entity.burner
  local currently_burning = burner.currently_burning

  local max_energy_usage = entity_prototype.max_energy_usage * (entity.consumption_bonus + 1)

  if currently_burning then
    local burns_per_second = 1 / (currently_burning.fuel_value / (max_energy_usage / burner_prototype.effectivity) / 60)
    calc_util.add_rate(
      rates,
      "input",
      "item",
      currently_burning.name,
      currently_burning.localised_name,
      burns_per_second,
      "entity/" .. entity.name
    )

    local burnt_result = currently_burning.burnt_result
    if burnt_result then
      calc_util.add_rate(
        rates,
        "output",
        "item",
        burnt_result.name,
        burnt_result.localised_name,
        burns_per_second,
        "entity/" .. entity.name
      )
    end

    return emissions_per_second
      + (burner_prototype.emissions * 60 * max_energy_usage * currently_burning.fuel_emissions_multiplier)
  end

  return emissions_per_second
end
