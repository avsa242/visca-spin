{
----------------------------------------------------------------------------------------------------
    Filename:       VISCA-Demo.spin
    Description:    Demo of the VISCA protocol
        * Controller
    Author:         Jesse Burt
    Started:        Jun 28, 2024
    Updated:        Jun 29, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = cfg._clkmode
    _xinfreq    = cfg._xinfreq

    CMD_DLY     = 50                            ' delay between commands (milliseconds)


OBJ

    cfg:    "boardcfg.flip"
    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    cam:    "com.serial.terminal.ansi" | RX_PIN=9, TX_PIN=8, SER_BAUD=9600, ...
                                            SIG_MODE=%0011  ' flags: invert RX and TX
    visca:  "protocol.camera.visca.spin"


pub main() | fw_v

    setup()

    { Tell the VISCA object what functions to use to talk to the camera.
        In this case, they're putchar() and getchar() from a serial object, but they could
        be anything that functions equivalently.

        putchar() needs to take one parameter (a byte)
        getchar() needs to take no parameters, but return a value (a byte) }

    visca.attach_funcs(@cam.putchar, @cam.getchar)

    visca.set_cam_id(1)                         ' set the camera ID number (usually 1)


    ser.printf2(@"Camera vendorid:modelid %04.4x:%04.4x\n\r", visca.vendor_id(), visca.model_id() )
    fw_v := visca.rom_version()
    ser.printf3(@"Firmware v%x.%x.%x\n\r",  nibble(fw_v, 2), ...
                                            nibble(fw_v, 1), ...
                                            nibble(fw_v, 0) )


    repeat
        ser.pos_xy(0, 4)
        ser.str(@help_text)
        case ser.getchar_noblock()
            "Q":
                visca.cam_zoom_in()
                time.msleep(CMD_DLY)
                visca.cam_zoom_stop()
            "q":
                visca.cam_zoom_out()
                time.msleep(CMD_DLY)
                visca.cam_zoom_stop()
            "W":
                visca.cam_focus_far()
                time.msleep(CMD_DLY)
                visca.cam_focus_stop()
            "w":
                visca.cam_focus_near()
                time.msleep(CMD_DLY)
                visca.cam_focus_stop()
            "s":
                visca.cam_focus_auto_toggle()
            "F":
                visca.cam_freeze_image()
            "f":
                visca.cam_unfreeze_image()


pub nibble(val, n): v
' Get a nibble from a source value
'   val:    value to extract nibble from
'   n:      nibble # (0-based)
'   Returns:
'       nibble extracted
    return (val >> (n << 2)) & $0f


PUB setup()

    ser.start()
    cam.start()                                 ' start the physical interface to the camera
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")


DAT

    help_text
        byte    "VISCA Demo - key input help", 10, 13
        byte    "---------------------------", 10, 13, 10, 13
        byte    "Q:     Zoom in (tele)", 10, 13
        byte    "q:     Zoom out (wide)", 10, 13
        byte    "W:     Focus farther", 10, 13
        byte    "w:     Focus nearer", 10, 13
        byte    "s:     Toggle autofocus", 10, 13
        byte    0


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
}

