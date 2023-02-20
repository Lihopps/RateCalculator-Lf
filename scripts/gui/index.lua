local format = require("__flib__.format")
local gui = require("__flib__.gui-beta")
local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("__RateCalculator__.constants")

local function format_tooltip_internal(amount)
  return format.number(math.round(amount, 0.001))
end

local function format_tooltip(data, key)
  local raw_total = data["total_" .. key]
  local total = format_tooltip_internal(raw_total)
  if data.owners then
    local result = ""
    for output, output_data in pairs(data.owners) do
      local line = "\n[img=" .. output .. "]  " .. format_tooltip_internal(output_data[key])
      result = result .. line
    end
    return { "gui.rcalc-detailed-tooltip", total, result }
  else
    return total
  end
end

local function format_caption(amount, precision)
  return format.number(amount, true, precision or 5)
end

local function total_label(label)
  return {
    type = "flow",
    style = "rcalc_totals_labels_flow",
    children = {
      { type = "label", style = "bold_label", caption = label },
      { type = "label" },
    },
  }
end

local function stacked_labels(width)
  return {
    type = "flow",
    style = "rcalc_stacked_labels_flow",
    style_mods = { width = width },
    direction = "vertical",
    children = {
      {
        type = "label",
        style = "rcalc_amount_label",
        style_mods = { font_color = constants.colors.output },
      },
      {
        type = "label",
        style = "rcalc_amount_label",
        style_mods = { font_color = constants.colors.input },
      },
    },
  }
end

local function frame_action_button(sprite, tooltip, action, ref)
  return {
    type = "sprite-button",
    style = "frame_action_button",
    sprite = sprite .. "_white",
    hovered_sprite = sprite .. "_black",
    clicked_sprite = sprite .. "_black",
    tooltip = tooltip,
    mouse_button_filter = { "left" },
    ref = ref,
    actions = {
      on_click = action,
    },
  }
end

local function set_warning(refs, caption)
  if caption then
    refs.list_frame.style = "rcalc_warning_frame_in_shallow_frame"
    refs.scroll_pane.visible = false
    refs.warning_flow.visible = true
    refs.warning_label.caption = caption
  else
    refs.list_frame.style = "deep_frame_in_shallow_frame"
    refs.scroll_pane.visible = true
    refs.warning_flow.visible = false
  end
end

--- @class SelectionGui
local SelectionGui = {}

SelectionGui.actions = require("__RateCalculator__.scripts.gui.actions")

function SelectionGui:destroy()
  if self.refs.window.valid then
    self.refs.window.destroy()
  end
  self.player_table.gui = nil
end

function SelectionGui:open()
  self.state.visible = true
  self.refs.window.visible = true

  if not self.state.pinned then
    self.player.opened = self.refs.window
  end
end

function SelectionGui:dispatch(action, e)
  local handler = self.actions[action]
  if handler then
    handler(self, e)
  end
end

--- @param reset boolean?
--- @param to_measure string?
function SelectionGui:update(reset, to_measure)
  local refs = self.refs
  local state = self.state

  -- Reset multiplier and navigation if a new selection was made
  if reset then
    state.selection_index = 1
    state.multiplier = 1
    refs.multiplier_textfield.style = "rcalc_multiplier_textfield"
    refs.multiplier_textfield.text = "1"
    refs.multiplier_slider.slider_value = 1
  end

  -- Update active measure if needed
  if to_measure then
    state.measure = to_measure
  end

  -- Update nav buttons
  local num_selections = #self.player_table.selections
  if state.selection_index < num_selections then
    refs.nav_backward_button.enabled = true
    refs.nav_backward_button.sprite = "rcalc_nav_backward_white"
  else
    refs.nav_backward_button.enabled = false
    refs.nav_backward_button.sprite = "rcalc_nav_backward_disabled"
  end
  if state.selection_index > 1 then
    refs.nav_forward_button.enabled = true
    refs.nav_forward_button.sprite = "rcalc_nav_forward_white"
  else
    refs.nav_forward_button.enabled = false
    refs.nav_forward_button.sprite = "rcalc_nav_forward_disabled"
  end

  -- Get unit data and update toolbar elements

  local measure = state.measure
  local measure_units = constants.units[measure]
  local units

  refs.measure_dropdown.selected_index = constants.measures[measure].index

  -- Unset active warning, if there is one
  set_warning(refs, nil)

  local units_button = refs.units_button
  local units_settings = state.units[measure]
  local selected_units = units_settings.selected
  local units_info = measure_units[selected_units]
  local selection_tool_button = refs.selection_tool_button
  if units_info.entity_filters then
    -- Get the data for the currently selected thing
    local currently_selected = units_settings[selected_units]
    if currently_selected then
      units = global.entity_rates[selected_units][currently_selected]
    else
      units = units_info.default_units
    end

    units_button.visible = true
    units_button.elem_filters = units_info.entity_filters
    units_button.elem_value = currently_selected
    selection_tool_button.visible = false
  elseif units_info.selection_tool then
    units_button.visible = false
    selection_tool_button.visible = true

    -- TODO: Un-hardcode this if we add any more selection tools
    local selected_inserter = self.player_table.selected_inserter
    if selected_inserter then
      units = { divisor = selected_inserter.rate, multiplier = 1, types = { item = true } }
      selection_tool_button.elem_value = selected_inserter.name
    else
      set_warning(refs, { "gui.rcalc-click-to-select-inserter" })
      selection_tool_button.elem_value = nil
    end
  else
    units = units_info.default_units
    units_button.visible = false
    selection_tool_button.visible = false
  end

  local units_dropdown = refs.units_dropdown
  local dropdown_items = constants.units_dropdowns[measure]
  if #dropdown_items == 1 then
    units_dropdown.enabled = false
  else
    units_dropdown.enabled = true
  end
  units_dropdown.items = dropdown_items
  units_dropdown.selected_index = units_info.index

  -- Update rates table

  local overall_output = 0
  local overall_input = 0

  if units then
    local rates = self.player_table.selections[state.selection_index][measure]
    local scroll_pane = refs.scroll_pane
    local children = scroll_pane.children

    local widths = constants.widths[self.player_table.locale or "en"] or constants.widths.en

    local search_query = state.search_query

    local item_prototypes = game.item_prototypes

    local i = 0
    for _, data in ipairs(rates) do
      local function apply_units(amount)
        if units.divide_by_stack_size then
          amount = amount / item_prototypes[data.name].stack_size
        end
        return (amount / units.divisor) * units.multiplier * state.multiplier
      end
      -- TODO: use translations
      if
        (not units.types or units.types[data.type])
        and string.find(string.gsub(data.name, "%-", " "), search_query, 1, true)
      then
        -- Assemble data

        local formatted = {
          inputs = {},
          outputs = {},
        }

        for key, formatted in pairs(formatted) do
          local data = data[key]
          formatted.total_amount = apply_units(data.total_amount)
          formatted.total_machines = data.total_machines * state.multiplier
          formatted.total_per_machine = formatted.total_machines ~= 0
              and (formatted.total_amount / formatted.total_machines)
            or 0
          if data.owners then
            formatted.owners = table.map(data.owners, function(owner_data)
              local amount = apply_units(owner_data.amount)
              return { amount = amount, machines = owner_data.machines, per_machine = amount / owner_data.machines }
            end)
          end
        end

        if formatted.outputs.total_amount > 0 and formatted.inputs.total_amount > 0 then
          local total_amount = math.round(formatted.outputs.total_amount - formatted.inputs.total_amount, 0.00001)
          formatted.net = {
            total_amount = total_amount,
            total_machines = total_amount / formatted.outputs.total_per_machine,
          }
        end

        overall_output = overall_output + formatted.outputs.total_amount
        overall_input = overall_input + formatted.inputs.total_amount

        -- Update GUI

        i = i + 1
        local frame = children[i]
        if not frame then
          frame = gui.add(scroll_pane, {
            type = "frame",
            style = "rcalc_rates_list_box_row_frame_" .. (i % 2 == 0 and "even" or "odd"),
            {
              type = "sprite-button",
              style = "transparent_slot",
            },
            stacked_labels(widths[1]),
            stacked_labels(widths[2]),
            stacked_labels(widths[3]),
            { type = "label", style = "rcalc_amount_label", style_mods = { width = widths[4] } },
            { type = "label", style = "rcalc_amount_label", style_mods = { width = widths[5] } },
          })
        end

        gui.update(frame, {
          {
            -- We have to explicitly set it to `nil` here, you can't put nil values in a table
            cb = function(elem)
              elem.number = data.temperature
            end,
            elem_mods = {
              sprite = data.type .. "/" .. string.gsub(data.name, "%..*$", ""),
              tooltip = data.localised_name,
            },
          },
          {
            {
              elem_mods = {
                caption = format_caption(formatted.outputs.total_amount),
                tooltip = format_tooltip(formatted.outputs, "amount"),
                visible = formatted.outputs.total_amount ~= 0,
              },
            },
            {
              elem_mods = {
                caption = format_caption(formatted.inputs.total_amount),
                tooltip = format_tooltip(formatted.inputs, "amount"),
                visible = formatted.inputs.total_amount ~= 0,
              },
            },
          },
          {
            {
              elem_mods = {
                caption = format_caption(formatted.outputs.total_machines, 1),
                tooltip = format_tooltip(formatted.outputs, "machines"),
                visible = formatted.outputs.total_machines > 0,
              },
            },
            {
              elem_mods = {
                caption = format_caption(formatted.inputs.total_machines, 1),
                tooltip = format_tooltip(formatted.inputs, "machines"),
                visible = formatted.inputs.total_machines > 0,
              },
            },
          },
          {
            {
              elem_mods = {
                caption = format_caption(formatted.outputs.total_per_machine),
                tooltip = format_tooltip(formatted.outputs, "per_machine"),
                visible = formatted.outputs.total_per_machine ~= 0,
              },
            },
            {
              elem_mods = {
                caption = format_caption(formatted.inputs.total_per_machine),
                tooltip = format_tooltip(formatted.inputs, "per_machine"),
                visible = formatted.inputs.total_per_machine ~= 0,
              },
            },
          },
          {
            style_mods = {
              font_color = (
                formatted.net
                  and constants.colors[formatted.net.total_amount < 0 and "input" or (formatted.net.total_amount > 0 and "output" or "white")]
                or constants.colors.white
              ),
            },
            elem_mods = {
              caption = formatted.net and format_caption(formatted.net.total_amount) or "--",
              tooltip = formatted.net and format_tooltip_internal(formatted.net.total_amount) or "",
            },
          },
          {
            style_mods = {
              font_color = (
                formatted.net
                  and constants.colors[formatted.net.total_machines < 0 and "input" or (formatted.net.total_machines > 0 and "output" or "white")]
                or constants.colors.white
              ),
            },
            elem_mods = {
              caption = formatted.net and format_caption(formatted.net.total_machines) or "--",
              tooltip = formatted.net and format_tooltip_internal(formatted.net.total_machines) or "",
            },
          },
        })
      end
    end

    for j = i + 1, #children do
      children[j].destroy()
    end

    if i == 0 then
      if #search_query > 0 then
        set_warning(refs, { "gui.rcalc-no-search-results" })
      else
        set_warning(refs, { "gui.rcalc-no-rates" })
      end
    end
  end

  local net_total = overall_output - overall_input

  -- Update totals
  if units and units_info.show_totals then
    gui.update(refs.totals_frame, {
      elem_mods = { visible = true },
      {},
      {},
      {
        {},
        {
          elem_mods = {
            caption = format_caption(overall_output),
            tooltip = format_tooltip_internal(overall_output),
          },
        },
      },
      {},
      {
        {},
        {
          elem_mods = {
            caption = format_caption(overall_input),
            tooltip = format_tooltip_internal(overall_input),
          },
        },
      },
      {},
      {
        {},
        {
          elem_mods = {
            caption = format_caption(net_total),
            tooltip = format_tooltip_internal(net_total),
          },
        },
      },
    })
  else
    refs.totals_frame.visible = false
  end
end

local index = {}

function index.build(player, player_table)
  local refs = gui.build(player.gui.screen, {
    {
      type = "frame",
      name = "rcalc_window",
      direction = "vertical",
      visible = false,
      ref = { "window" },
      actions = {
        on_closed = "close",
      },
      {
        type = "flow",
        style = "flib_titlebar_flow",
        ref = { "titlebar_flow" },
        actions = {
          on_click = "recenter",
        },
        frame_action_button(
          "rcalc_nav_backward",
          { "gui.rcalc-previous-selection" },
          "nav_backward",
          { "nav_backward_button" }
        ),
        frame_action_button(
          "rcalc_nav_forward",
          { "gui.rcalc-next-selection" },
          "nav_forward",
          { "nav_forward_button" }
        ),
        {
          type = "label",
          style = "frame_title",
          style_mods = { left_margin = 4 },
          caption = { "mod-name.RateCalculator" },
          ignored_by_interaction = true,
        },
        { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
        {
          type = "textfield",
          style_mods = { top_margin = -3, width = 150 },
          visible = false,
          ref = { "search_textfield" },
          actions = {
            on_text_changed = "update_search_query",
          },
        },
        frame_action_button("utility/search", { "gui.rcalc-search-instruction" }, "toggle_search", { "search_button" }),
        frame_action_button("rcalc_pin", { "gui.rcalc-keep-open" }, "toggle_pinned", { "pin_button" }),
        frame_action_button("utility/close", { "gui.close-instruction" }, "close"),
      },
      {
        type = "frame",
        style = "inside_shallow_frame",
        direction = "vertical",
        {
          type = "frame",
          style = "rcalc_toolbar_frame",
          { type = "label", style = "subheader_caption_label", caption = { "gui.rcalc-measure-label" } },
          {
            type = "drop-down",
            items = constants.measures_dropdown,
            ref = { "measure_dropdown" },
            actions = {
              on_selection_state_changed = "update_measure",
            },
          },
          { type = "empty-widget", style = "flib_horizontal_pusher" },
          { type = "label", style = "caption_label", caption = { "gui.rcalc-units-label" } },
          {
            type = "choose-elem-button",
            style = "rcalc_units_choose_elem_button",
            style_mods = { right_margin = -8 },
            elem_type = "entity",
            ref = { "units_button" },
            actions = {
              on_elem_changed = "update_units_button",
            },
          },
          {
            type = "choose-elem-button",
            style = "rcalc_units_choose_elem_button",
            style_mods = { right_margin = -8 },
            elem_type = "entity",
            elem_mods = { locked = true },
            ref = { "selection_tool_button" },
            actions = {
              on_click = "give_selection_tool",
            },
          },
          {
            type = "drop-down",
            ref = { "units_dropdown" },
            actions = {
              on_selection_state_changed = "update_units_dropdown",
            },
          },
        },
        {
          type = "flow",
          style_mods = { padding = 12, margin = 0 },
          {
            type = "frame",
            style = "deep_frame_in_shallow_frame",
            direction = "vertical",
            ref = { "list_frame" },
            {
              type = "frame",
              style = "rcalc_toolbar_frame",
              style_mods = { right_padding = 20 },
              { type = "label", style = "rcalc_column_label", style_mods = { width = 32 }, caption = "--" },
              { type = "label", style = "rcalc_column_label", caption = { "gui.rcalc-rate" } },
              { type = "label", style = "rcalc_column_label", caption = { "gui.rcalc-machines" } },
              { type = "label", style = "rcalc_column_label", caption = { "gui.rcalc-per-machine" } },
              { type = "label", style = "rcalc_column_label", caption = { "gui.rcalc-net-rate" } },
              { type = "label", style = "rcalc_column_label", caption = { "gui.rcalc-net-machines" } },
            },
            {
              type = "scroll-pane",
              style = "rcalc_rates_list_box_scroll_pane",
              horizontal_scroll_policy = "never",
              ref = { "scroll_pane" },
            },
            {
              type = "flow",
              style = "rcalc_warning_flow",
              visible = false,
              ref = { "warning_flow" },
              {
                type = "label",
                style = "bold_label",
                caption = { "gui.rcalc-click-to-select-inserter" },
                ref = { "warning_label" },
              },
            },
            {
              type = "frame",
              style = "rcalc_totals_frame",
              ref = { "totals_frame" },
              { type = "label", style = "caption_label", caption = { "gui.rcalc-totals-label" } },
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              total_label({ "gui.rcalc-output-label" }),
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              total_label({ "gui.rcalc-input-label" }),
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              total_label({ "gui.rcalc-net-label" }),
            },
          },
        },
        {
          type = "frame",
          style = "rcalc_multiplier_frame",
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "gui.rcalc-multiplier-label" },
          },
          {
            type = "slider",
            style = "rcalc_multiplier_slider",
            minimum_value = 1,
            maximum_value = 100,
            value_step = 1,
            ref = { "multiplier_slider" },
            actions = {
              on_value_changed = "update_multiplier_slider",
            },
          },
          {
            type = "textfield",
            style = "rcalc_multiplier_textfield",
            numeric = true,
            allow_decimal = true,
            clear_and_focus_on_right_click = true,
            lose_focus_on_confirm = true,
            text = "1",
            ref = { "multiplier_textfield" },
            actions = {
              on_text_changed = "update_multiplier_textfield",
            },
          },
        },
      },
    },
  })

  refs.titlebar_flow.drag_target = refs.window
  refs.window.force_auto_center()

  -- Assemble default settings table
  local measure = next(constants.measures)
  local units = {}
  for measure_name, units_list in pairs(constants.units) do
    local measure_settings = {}
    for unit_name, unit_data in pairs(units_list) do
      if unit_data.default then
        measure_settings.selected = unit_name
      end
      if unit_data.entity_filters and not unit_data.default_units then
        -- Get the first entry in the table - `next()` does not work here since it's a LuaCustomTable
        for name in pairs(game.get_filtered_entity_prototypes(unit_data.entity_filters)) do
          measure_settings[unit_name] = name
          break
        end
      end
    end
    units[measure_name] = measure_settings
  end

  --- @class SelectionGui
  local self = {
    player = player,
    player_table = player_table,
    refs = refs,
    state = {
      measure = measure,
      multiplier = 1,
      pinned = false,
      pinning = false,
      selection_index = 1,
      search_open = false,
      search_query = "",
      units = units,
      visible = false,
    },
  }

  index.load(self)

  player_table.gui = self
end

--- @param Gui SelectionGui
function index.load(Gui)
  setmetatable(Gui, { __index = SelectionGui })
end

return index
