local wezterm = require("wezterm")
local fs = require('fs')
local pane_mod = require('pane')
local pub = {}

--- Retrieves tab data
-- @param tab wezterm.Tab: The tab to retrieve data from.
-- @return table: The tab data table.
function pub.retrieve_tab_data(tab)
    local tab_data = {
        tab_id = tostring(tab:tab_id()),
        panes = {}
    }

    -- Iterate over panes in the current tab
    for _, pane_info in ipairs(tab:panes_with_info()) do
        -- Collect pane details, including layout and process information
        local pane_data = pane_mod.retrieve_pane_data(pane_info)
        table.insert(tab_data.panes, pane_data)
    end

    return tab_data
end

function pub.restore_tab(window, tab_data)
    local cwd_uri = tab_data.panes[1].cwd
    local cwd_path = fs.extract_path_from_dir(cwd_uri)

    local new_tab = window:mux_window():spawn_tab({ cwd = cwd_path })
    if not new_tab then
        wezterm.log_info("Failed to create a new tab.")
        return
    end

    -- Activate the new tab before creating panes
    new_tab:activate()

    -- Recreate panes within this tab
    pub.restore_panes(window, new_tab, tab_data)
    -- for j, pane_data in ipairs(tab_data.panes) do
    --     pane_mod.restore_pane(window, new_tab, tab_data, j, pane_data)
    -- end
end

local function find_horizontal_split(p, tab_data)
    local spanel = nil
    local idx = nil
    for j, pane_data in ipairs(tab_data.panes) do
        if pane_data.top == p.top and pane_data.left == (p.left + p.width + 1) then
            spanel = pane_data
            idx = j
        end
    end
    return spanel, idx
end

local function find_vertical_split(p, tab_data)
    local spanel = nil
    local idx = nil
    for j, pane_data in ipairs(tab_data.panes) do
        if pane_data.left == p.left and pane_data.top == (p.top + p.height + 1) then
            spanel = pane_data
            idx = j
        end
    end
    return spanel, idx
end

local function get_tab_width(tab_data)
    local width = 0
    for _, pane_data in ipairs(tab_data.panes) do
        if pane_data.top == 0 then
            width = width + pane_data.width
        end
    end
    return width
end

local function get_tab_height(tab_data)
    local height = 0
    for _, pane_data in ipairs(tab_data.panes) do
        if pane_data.left == 0 then
            height = height + pane_data.height
        end
    end
    return height
end

local function split_horizontally(window, tab, tab_width, ipanes, ipane, panes, hpane)
    wezterm.log_info("Split horizontally", ipane.top, ipane.left)
    wezterm.log_info("Restoring pane", tab_width, ipane.left, hpane.left)
    local available_width = tab_width - ipane.left
    local new_pane = tab:active_pane():split({
        direction = 'Right',
        cwd = fs.extract_path_from_dir(hpane.cwd),
        size = 1 - ((hpane.left - ipane.left) / available_width)
    })
    table.insert(ipanes, hpane)
    table.insert(panes, new_pane)
    pane_mod.restore_pane(window, new_pane, hpane)
end

local function split_vertically(window, tab, tab_height, ipanes, ipane, panes, vpane)
    wezterm.log_info("Split vertically", ipane.top, ipane.left)
    local available_height = tab_height - ipane.top
    local new_pane = tab:active_pane():split({
        direction = 'Bottom',
        cwd = fs.extract_path_from_dir(vpane.cwd),
        size = 1 - ((vpane.top - ipane.top) / available_height)
    })
    table.insert(ipanes, vpane)
    table.insert(panes, new_pane)
    pane_mod.restore_pane(window, new_pane, vpane)
end

local function activate_panel(p)
    wezterm.sleep_ms(200)
    p:activate()
    wezterm.sleep_ms(200)
end


function pub.restore_panes(window, tab, tab_data)
    -- keeps track of actually created panes
    local ipanes = { tab_data.panes[1] }
    local panes = { tab:active_pane() }
    local tab_width = get_tab_width(tab_data)
    local tab_height = get_tab_height(tab_data)

    -- sleep is needed to let pane focus have effect
    for idx, p in ipairs(panes) do
        -- restore first pane
        if idx == 1 then
            pane_mod.restore_pane(window, p, tab_data.panes[1])
        end

        activate_panel(p)

        local hpane, hj = find_horizontal_split(ipanes[idx], tab_data)
        local vpane, vj = find_vertical_split(ipanes[idx], tab_data)

        if hj ~= nil and (vj == nil or vj < hj) then -- I though here should be vj < hj but it works this way
            split_horizontally(window, tab, tab_width, ipanes, ipanes[idx], panes, hpane)
            activate_panel(p)
            if vj ~= nil then
                split_vertically(window, tab, tab_height, ipanes, ipanes[idx], panes, vpane)
                activate_panel(p)
            end
        elseif vj ~= nil then
            split_vertically(window, tab, tab_height, ipanes, ipanes[idx], panes, vpane)
            activate_panel(p)
            if hj ~= nil then
                split_horizontally(window, tab, tab_width, ipanes, ipanes[idx], panes, hpane)
            end
        end
    end

    wezterm.log_info("Finished")
end

return pub
