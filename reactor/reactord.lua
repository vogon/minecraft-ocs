local component = require('component')
local event = require('event')
local os = require('os')
local term = require('term')
local events = require('reactord_events')

local br = component.br_reactor

local MAX_REACTOR_BUFFER = 10000000
local REACTOR_LO_BUFFER_TRIP = 0.1
local REACTOR_HI_BUFFER_TRIP = 0.9

local trip_mode = 'automatic'

local telemetry_poll_timer
local set_trip_mode_listener
local set_all_rods_level_listener

local function telemetry_poll()
    local data = {}

    data['trip_mode'] = trip_mode
    data['reactor_active'] = br.getActive()

    local energy_stored = br.getEnergyStored()
    data['energy_stored'] = energy_stored

    data['fuel_temp'] = br.getFuelTemperature()
    data['casing_temp'] = br.getCasingTemperature()
    data['energy_produced_last_tick'] = br.getEnergyProducedLastTick()

    data['rod_positions'] = {}

    for rod=0, br.getNumberOfControlRods() - 1 do
        data['rod_positions'][rod] = br.getControlRodLevel(rod)
    end
    
    if trip_mode == 'override on' then
        br.setActive(true)
    elseif trip_mode == 'override off' then
        br.setActive(false)
    elseif trip_mode == 'automatic' then
        if energy_stored / MAX_REACTOR_BUFFER < REACTOR_LO_BUFFER_TRIP then
            br.setActive(true)
        elseif energy_stored / MAX_REACTOR_BUFFER > REACTOR_HI_BUFFER_TRIP then
            br.setActive(false)
        end
    end

    event.push(events.telemetry_poll, data)
end

local function set_trip_mode(_, mode)
    trip_mode = mode
end

local function set_all_rods_level(_, level)
    br.setAllControlRodLevels(level)
end

function start()
    telemetry_poll_timer = event.timer(0.5, telemetry_poll, math.huge)
    set_trip_mode_listener = event.listen(events.set_trip_mode, set_trip_mode)
    set_all_rods_level_listener = event.listen(events.set_all_rods_level,
        set_all_rods_level)
end

function stop()
    event.cancel(telemetry_poll_timer)
    event.cancel(set_trip_mode_listener)
    event.cancel(set_all_rods_level_listener)
end
