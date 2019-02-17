local event = require('event')
local events = require('reactord_events')

local last_data = {}

local should_exit = false

function on_key_up(_, kbd_address, char, code, player_name)
    print('on_key_up')
    local old_pos = last_data['rod_positions'][0]
    local new_pos

    if string.char(char) == 'i' then
        new_pos = old_pos + 1
    elseif string.char(char) == 'o' then
        new_pos = old_pos - 1
    elseif string.char(char) == 't' then
        if trip_mode == 'automatic' then
            event.push(events.set_trip_mode, 'override on')
        elseif trip_mode == 'override on' then
            event.push(events.set_trip_mode, 'override off')
        else
            event.push(events.set_trip_mode, 'automatic')
        end
    end

    if new_pos > 100 then
        new_pos = 100
    elseif new_pos < 0 then
        new_pos = 0
    end  

    event.push(events.set_all_rods_level, new_pos)
end

function on_telemetry_poll(_, data)
    last_data = data

    term.clear()

    print('trip mode:', data['trip_mode'])
    print('reactor active:', data['reactor_active'])
    print('power buffer:', string.format('%d RF', data['energy_stored']))
    print('fuel temp:', string.format('%f oC', data['fuel_temp']))
    print('casing temp:', string.format('%f oC', data['casing_temp']))
    print('energy output:', string.format('%f RF', data['energy_produced_last_tick']))

    for index, value in ipairs(data['rod_positions']) do
        print(string.format('rod %d pos:', index), string.format('%d%%', value))
    end

    print()
    print('t: trip mode')
    print('i: control rods in 1%')
    print('o: control rods out 1%')
end

local key_up_listener = event.listen('key_up', on_key_up)
local telemetry_poll_listener = event.listen(events.telemetry_poll, 
    on_telemetry_poll)

function on_interrupted()
    should_exit = true
    event.cancel(key_up_listener)
    event.cancel(telemetry_poll_listener)
end

event.listen('interrupted', on_interrupted)

while not should_exit do
    os.sleep(0.5)
end
