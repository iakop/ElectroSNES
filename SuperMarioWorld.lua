-- Script to use with Snes9x-rr
-- Author: Jacob Bechmann Pedersen
-- Date: 2021-03-11

print("Starting script")

-- Load environment
local gui, emu, memory = gui, emu, memory
local string, math = string, math

-- math
local floor = math.floor

-- unsigned to signed (based in <bits> bits)
local function signed(num, bits)
    local maxval = 2^(bits - 1)
    if num < maxval then return num else return num - 2*maxval end
end

-- Compatibility of the memory read/write functions
local u8 =  memory.readbyte
local s8 =  memory.readbytesigned
local w8 =  memory.writebyte
local u16 = memory.readword
local s16 = memory.readwordsigned
local w16 = memory.writeword
local u24 = function(address, value) return 256*u16(address + 1) + u8(address) end
local s24 = function(address, value) return signed(256*u16(address + 1) + u8(address), 24) end
local w24 = function(address, value) w16(address + 1, floor(value/256)) ; w8(address, value%256) end

--#############################################################################
-- GAME AND SNES SPECIFIC MACROS:
local modes = {
	ZAP_MODE = 0x1,
	RUMBLE_MODE = 0x2,
	BEEP_MODE = 0x4,
	BLINK_MODE = 0x8,
}


local settings = {
	mode = modes.ZAP_MODE, -- the player will be zapped
	power = 10,
	duration = 1500, -- 1500 ms
}

local NTSC_FRAMERATE = 60.0

local SMW = {
    game_mode_overworld = 0x0e,
    game_mode_level = 0x14,
}

local WRAM = {
    game_mode = 0x7e0100,
    lock_animation_flag = 0x7e009d, -- Most codes will still run if this is set, but almost nothing will move or animate.
}

local lock_codes = {
    none = 0x00,
    shrink = 0x2F,
    death = 0x30,
    yoshi_start = 0x40,
    yoshi_end = 0x02,
}

-- Arduino Serial communication
local rs232 = require("luars232")
local port_name = "COM8"

local function connect_to_arduino()
    -- test port:
    -- open port
    local e, p = rs232.open(port_name)
    if e ~= rs232.RS232_ERR_NOERROR then
        -- handle error
        print(string.format("can't open serial port '%s', error: '%s'\n",
                port_name, rs232.error_tostring(e)))
        return
    end
    print(string.format("OK, port found and open with values '%s'\n", tostring(p)))
    -- close
    assert(p:close() == rs232.RS232_ERR_NOERROR)
end

local function write_to_arduino(str)
    -- use port:
    -- open port
    local e, p = rs232.open(port_name)
    if e ~= rs232.RS232_ERR_NOERROR then
        -- handle error
        print(string.format("can't open serial port '%s', error: '%s'\n",
                port_name, rs232.error_tostring(e)))
        return
    end
    -- set port settings
    assert(p:set_baud_rate(rs232.RS232_BAUD_115200) == rs232.RS232_ERR_NOERROR)
    assert(p:set_data_bits(rs232.RS232_DATA_8) == rs232.RS232_ERR_NOERROR)
    assert(p:set_parity(rs232.RS232_PARITY_NONE) == rs232.RS232_ERR_NOERROR)
    assert(p:set_stop_bits(rs232.RS232_STOP_1) == rs232.RS232_ERR_NOERROR)
    assert(p:set_flow_control(rs232.RS232_FLOW_OFF)  == rs232.RS232_ERR_NOERROR)

    -- write without timeout
    local err, len_written = p:write(str)
    assert(e == rs232.RS232_ERR_NOERROR)

    -- close
    assert(p:close() == rs232.RS232_ERR_NOERROR)
end

local function scan_smw()
    Game_mode = u8(WRAM.game_mode)
    Lock_animation_flag = u8(WRAM.lock_animation_flag)
end

last_lock_animation_flag = 0
local function check_for_damage()
    if Game_mode == SMW.game_mode_level then
        if (Lock_animation_flag == lock_codes.death
            or Lock_animation_flag == lock_codes.shrink)
        and last_lock_animation_flag == lock_codes.none then
            write_to_arduino("cmd:" .. settings.mode .. ":" .. settings.power .. ":" .. settings.duration .. ";")
            print("Hit detected!")
            print("cmd:" .. settings.mode .. ":" .. settings.power .. ":" .. settings.duration .. ";")
        elseif Lock_animation_flag == lock_codes.none
        and (Lock_animation_flag == lock_codes.death
            or Lock_animation_flag == lock_codes.shrink) then
            print("Now unhit :)")
        end
        last_lock_animation_flag = Lock_animation_flag
    else
        if Lock_animation_flag ~= lock_codes.none and last_lock_animation_flag ~= lock_codes.none then
            print("Now unhit :)")
            last_lock_animation_flag = lock_codes.none
        end
    end
end

--#############################################################################
--MAIN

connect_to_arduino()

gui.register(function()
    -- Drawings are allowed now
    scan_smw()
    check_for_damage()
end)

print("Lua script loaded successfully.")
