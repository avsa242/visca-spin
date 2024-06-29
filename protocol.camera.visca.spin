{
----------------------------------------------------------------------------------------------------
    Filename:       protocol.camera.visca.spin
    Description:    Implementation of Sony's VISCA camera protocol (controller)
    Author:         Jesse Burt
    Started:        Jun 28, 2024
    Updated:        Jun 29, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

con

    { limits }
    MSG_LEN_MIN         = 3
    MSG_LEN_MAX         = 16
    PAYLD_LEN_MIN       = 1
    PAYLD_LEN_MAX       = 14

    { byte 0 }
    START_BIT           = (1 << 7)
    SRC                 = 4
    DEST                = 0
    BROADCAST           = 8

    MSG_TYPE_BITS       = %1111 << 4

    { command types }
    CTRL_CMD            = $01
    INQ_CMD             = $09
    CANCEL_CMD          = $20
    ADDR_SET_CMD        = $30

    { network change message }
    NET_CHANGE          = $38

    { response types }
    RESPTYPE_MASK       = $f0
    ACK                 = $40
    COMPLETION          = $50
    ERROR               = $60
        { ERROR subtypes }
        SYNTAX_ERR      = $02
        CMD_BUFF_FULL   = $03
        CMD_CANCELED    = $04
        NO_SOCKET       = $05
        CMD_NOT_EXEC    = $41

    TERMINATE           = $ff                   ' message framing


var

    long putchar, getchar                       ' func pointers
    long _dbg                                   ' debug object pointer

    byte _buff[MSG_LEN_MAX]
    byte _src_addr
    byte _net_change
    byte _last_rcvd_id
    byte _cam_id


obj

    ser= "com.serial.terminal.ansi"             ' "virtual" instance of serial object


con

    PARM                    = $20
    ONOFF                   = $30
    DIRECT                  = $40

    { CAM_ commands }
    CAM_CMD                 = $04
        CAM_PWR             = $00
        CAM_ZOOM            = $07
            ZOOM_STOP       = $00
            ZOOM_TELE       = $02
            ZOOM_WIDE       = $03
            ZOOM_TELE_VAR   = $20
            ZOOM_WIDE_VAR   = $30

        CAM_APERTURE        = $02
            APERTURE_RES    = $00
            APERTURE_UP     = $02
            APERTURE_DN     = $03

        CAM_RGAIN           = $03
            RGAIN_RESET     = $00
            RGAIN_UP        = $02
            RGAIN_DOWN      = $03

        CAM_BGAIN           = $04
            BGAIN_RESET     = $00
            BGAIN_UP        = $02
            BGAIN_DOWN      = $03

        CAM_FOCUS           = $08
            FOCUS_STOP      = $00
            FOCUS_FAR       = $02
            FOCUS_NEAR      = $03
            FOCUS_FAR_VAR   = $20
            FOCUS_NEAR_VAR  = $30

        CAM_SHUTTER         = $0a
            SHUTTER_RES     = $00
            SHUTTER_UP      = $02
            SHUTTER_DN      = $03

        CAM_IRIS            = $0b
            IRIS_RES        = $00
            IRIS_UP         = $02
            IRIS_DN         = $03

        CAM_GAIN            = $0c
            GAIN_RES        = $00
            GAIN_UP         = $02
            GAIN_DN         = $03

        CAM_BRIGHT          = $0d
            BRIGHT_RESET    = $00
            BRIGHT_UP       = $02
            BRIGHT_DN       = $03

        CAM_EXPCOMP         = $0e
            EXPCOMP_RESET   = $00
            EXPCOMP_ON      = $02
            EXPCOMP_OFF     = $03
            EXPCOMP_UP      = $02
            EXPCOMP_DOWN    = $03

        CAM_IR_CORRECTION   = $11
            IR_CORR_STD     = $00
            IR_CORR_IR      = $01

        CAM_INITIALIZE      = $19
            INIT_LENS       = $01
            INIT_CAMERA     = $03

        REG_VAL             = $24

        CAM_BACKLIGHT       = $33
            BACKLIGHT_ON    = $02
            BACKLIGHT_OFF   = $03

        CAM_WHITEBAL        = $35
            WB_AUTO         = $00
            WB_INDOOR       = $01
            WB_OUTDOOR      = $02
            WB_ONEPUSH      = $03
            WB_ATW          = $04
            WB_MANUAL       = $05

        CAM_AUTOFOCUS       = $38
            FOCUS_AUTO      = $02
            FOCUS_MANUAL    = $03
            FOCUS_AUTO_TOG  = $10

        CAM_AE_MODE         = $39
            AE_FULLAUTO     = $00
            AE_MANUAL       = $03
            AE_SHUTTER_PRI  = $0a
            AE_IRIS_PRI     = $0b
            AE_BRIGHT       = $0d

        CAM_WD              = $3d
            WD_ON           = $02
            WD_OFF          = $03

        CAM_HIGHRES         = $52
            HIGHRES_ON      = $02
            HIGHRES_OFF     = $03

        CAM_NOISEREDUCT     = $53

        CAM_AF_MODE         = $57
            AF_MD_NORMAL    = $00
            AF_MD_INTERVAL  = $01
            AF_MD_ZOOM_TRIG = $02
            AF_MD_PRESET    = $03

        CAM_AF_SENS         = $58
            AF_SENS_HIGH    = $02
            AF_SENS_LOW     = $03

        CAM_SLSHUT          = $5a
            SLSHUT_AUTO     = $02
            SLSHUT_MAN      = $03

        CAM_GAMMA           = $5b

        CAM_HIGHSENS        = $5e
            HIGHSENS_ON     = $02
            HIGHSENS_OFF    = $03

        CAM_LR_REVERSE      = $61
            LR_REVERSE_ON   = $02
            LR_REVERSE_OFF  = $03

        CAM_FREEZE          = $62
            FREEZE_ON       = $02
            FREEZE_OFF      = $03

        CAM_PICEFFECT       = $63
            PICEFFECT_OFF   = $00
            PICEFFECT_NEG   = $02
            PICEFFECT_BW    = $04

        CAM_PICFLIP         = $66
            PICFLIP_ON      = $02
            PICFLIP_OFF     = $03

    IF_INQ                  = $00
        DEV_TYPE            = $02


pub attach_dbg(optr)
' Attach a debugging output object
    _dbg := optr


pub attach_funcs(p_tx, p_rx)
' Attach to putchar() and getchar() functions
'   p_tx:   pointer to putchar() function
'   p_rx:   pointer to getchar() function
    putchar := p_tx
    getchar := p_rx


pub cam_aperture_down(): s | cmd_pkt
' Decrease aperture
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_APERTURE
    cmd_pkt.byte[2] := APERTURE_DN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_aperture_reset(): s | cmd_pkt
' Reset aperture to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_APERTURE
    cmd_pkt.byte[2] := APERTURE_RES
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_aperture_up(): s | cmd_pkt
' Increase aperture
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_APERTURE
    cmd_pkt.byte[2] := APERTURE_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_autoexposure_mode(md): s | cmd_pkt
' Set camera auto-exposure mode
'   md:
'       AE_FULLAUTO ($00):      automatic exposure mode
'       AE_MANUAL ($03):        manual control
'       AE_SHUTTER_PRI ($0a):   shutter priority automatic exposure
'       AE_IRIS_PRI ($0b):      iris priority automatic exposure
'       AE_BRIGHT ($0d):        bright mode (manual control)
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AE_MODE
    cmd_pkt.byte[2] := AE_FULLAUTO #> md <# AE_BRIGHT
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_autofocus_mode(md): s | cmd_pkt
' Set camera autofocus sensitivity
'   md:
'       AF_MD_NORMAL ($00)
'       AF_MD_INTERVAL ($01)
'       AF_MD_ZOOM_TRIG ($02)
'       AF_MD_PRESET ($03)
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AF_MODE
    cmd_pkt.byte[2] := AF_MD_NORMAL #> md <# AF_MD_PRESET
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_autofocus_sensitivity(sens): s | cmd_pkt
' Set camera autofocus sensitivity
'   sens:
'       AF_SENS_HIGH ($02): normal/high sensitivity
'       AF_SENS_LOW ($03):  low sensitivity
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AF_SENS
    cmd_pkt.byte[2] := AF_SENS_HIGH #> sens <# AF_SENS_LOW
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_backlight_comp_off(): s | cmd_pkt
' Disable backlight compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BACKLIGHT
    cmd_pkt.byte[2] := BACKLIGHT_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_backlight_comp_on(): s | cmd_pkt
' Enable backlight compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BACKLIGHT
    cmd_pkt.byte[2] := BACKLIGHT_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_bluegain_down(): s | cmd_pkt
' Decrease blue gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BGAIN
    cmd_pkt.byte[2] := BGAIN_DOWN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_bluegain_reset(): s | cmd_pkt
' Reset blue gain to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BGAIN
    cmd_pkt.byte[2] := BGAIN_RESET
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_bluegain_up(): s | cmd_pkt
' Increase blue gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BGAIN
    cmd_pkt.byte[2] := BGAIN_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_brightness_down(): s | cmd_pkt
' Decrease brightness
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BRIGHT
    cmd_pkt.byte[2] := BRIGHT_DN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_brightness_reset(): s | cmd_pkt
' Reset brightness to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BRIGHT
    cmd_pkt.byte[2] := BRIGHT_RESET
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_brightness_up(): s | cmd_pkt
' Increase brightness
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_BRIGHT
    cmd_pkt.byte[2] := BRIGHT_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_exp_compensation_down(): s | cmd_pkt
' Decrease exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_EXPCOMP
    cmd_pkt.byte[2] := EXPCOMP_DOWN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_exp_compensation_off(): s | cmd_pkt
' Disable exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := (CAM_EXPCOMP | ONOFF)
    cmd_pkt.byte[2] := EXPCOMP_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_exp_compensation_on(): s | cmd_pkt
' Enable exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := (CAM_EXPCOMP | ONOFF)
    cmd_pkt.byte[2] := EXPCOMP_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_exp_compensation_reset(): s | cmd_pkt
' Reset exposure compensation to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_EXPCOMP
    cmd_pkt.byte[2] := EXPCOMP_RESET
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_exp_compensation_up(): s | cmd_pkt
' Increase exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_EXPCOMP
    cmd_pkt.byte[2] := EXPCOMP_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_auto(): s | cmd_pkt
' Enable camera auto-focus
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AUTOFOCUS
    cmd_pkt.byte[2] := FOCUS_AUTO
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_auto_toggle(): s | cmd_pkt
' Toggle between automatic and manual focus
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AUTOFOCUS
    cmd_pkt.byte[2] := FOCUS_AUTO_TOG
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_far(): s | cmd_pkt
' Manually focus camera farther
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_FOCUS
    cmd_pkt.byte[2] := FOCUS_FAR
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_manual(): s | cmd_pkt
' Enable camera manual-focus
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_AUTOFOCUS
    cmd_pkt.byte[2] := FOCUS_MANUAL
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_near(): s | cmd_pkt
' Manually focus camera nearer
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_FOCUS
    cmd_pkt.byte[2] := FOCUS_NEAR
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_focus_stop(): s | cmd_pkt
' Stop a running focus operation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_FOCUS
    cmd_pkt.byte[2] := FOCUS_STOP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_freeze_image(): s | cmd_pkt
' Freeze the camera image
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_FREEZE
    cmd_pkt.byte[2] := FREEZE_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_gain_down(): s | cmd_pkt
' Decrease gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_GAIN
    cmd_pkt.byte[2] := GAIN_DN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_gain_reset(): s | cmd_pkt
' Reset gain to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_GAIN
    cmd_pkt.byte[2] := GAIN_RES
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_gain_up(): s | cmd_pkt
' Increase gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_GAIN
    cmd_pkt.byte[2] := GAIN_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_high_sens_off(): s | cmd_pkt
' Disable high sensitivity mode
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_HIGHSENS
    cmd_pkt.byte[2] := HIGHSENS_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_high_sens_on(): s | cmd_pkt
' Enable high sensitivity mode
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_HIGHSENS
    cmd_pkt.byte[2] := HIGHSENS_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_highres_off(): s | cmd_pkt
' Disable exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_HIGHRES
    cmd_pkt.byte[2] := HIGHRES_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_highres_on(): s | cmd_pkt
' Enable exposure compensation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_HIGHRES
    cmd_pkt.byte[2] := HIGHRES_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_init_camera(): s | cmd_pkt
' Initialize/reset camera
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_INITIALIZE
    cmd_pkt.byte[2] := INIT_CAMERA
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_init_lens(): s | cmd_pkt
' Initialize lens
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_INITIALIZE
    cmd_pkt.byte[2] := INIT_LENS
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_ir_correction_mode(md): s | cmd_pkt
' Set focus IR compensation data switching mode
'   md:
'       IR_CORR_STD ($00):  standard
'       IR_CORR_IR ($01):   IR
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_IR_CORRECTION
    cmd_pkt.byte[2] := IR_CORR_STD #> md <# IR_CORR_IR
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_iris_down(): s | cmd_pkt
' Iris down
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_IRIS
    cmd_pkt.byte[2] := IRIS_DN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )

pub cam_iris_reset(): s | cmd_pkt
' Iris reset
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_IRIS
    cmd_pkt.byte[2] := IRIS_RES
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )

pub cam_iris_up(): s | cmd_pkt
' Iris up
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_IRIS
    cmd_pkt.byte[2] := IRIS_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_mirror_h_off(): s | cmd_pkt
' Do not mirror camera image horizontally
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_LR_REVERSE
    cmd_pkt.byte[2] := LR_REVERSE_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_mirror_h_on(): s | cmd_pkt
' Mirror camera image horizontally
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_LR_REVERSE
    cmd_pkt.byte[2] := LR_REVERSE_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_mirror_v_off(): s | cmd_pkt
' Do not mirror camera image vertically
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_PICFLIP
    cmd_pkt.byte[2] := PICFLIP_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_mirror_v_on(): s | cmd_pkt
' Mirror camera image vertically
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_PICFLIP
    cmd_pkt.byte[2] := PICFLIP_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_picture_effect(eff): s | cmd_pkt
' Set picture effect
'   eff:
'       PICEFFECT_OFF ($00):    no effect
'       PICEFFECT_NEG ($02):    negative
'       PICEFFECT_BW ($04):     black & white
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    ifnot ( lookdown(eff: PICEFFECT_OFF, PICEFFECT_NEG, PICEFFECT_BW) )
        return -1
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_PICEFFECT
    cmd_pkt.byte[2] := eff
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_power(pwr): s | cmd_pkt
' Power on camera
'   pwr:
'       TRUE (non-zero values): power on
'       FALSE (0): power off
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_PWR
    cmd_pkt.byte[2] := (pwr) ? $02 : $03        ' non-zero? Power on; else power off.
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_redgain_down(): s | cmd_pkt
' Decrease red gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_RGAIN
    cmd_pkt.byte[2] := RGAIN_DOWN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_redgain_reset(): s | cmd_pkt
' Reset red gain to camera default
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_RGAIN
    cmd_pkt.byte[2] := RGAIN_RESET
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_redgain_up(): s | cmd_pkt
' Increase red gain
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_RGAIN
    cmd_pkt.byte[2] := RGAIN_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_set_gamma(lev): s | cmd_pkt
' Set gamma level
'   lev:
'       0 (standard), 1..6
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_GAMMA
    cmd_pkt.byte[2] := 0 #> lev <# 6
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_set_noise_reduction(lev): s | cmd_pkt
' Set noise reduction level
'   lev:
'       0 (off), 1..5
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_NOISEREDUCT
    cmd_pkt.byte[2] := 0 #> lev <# 5
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_shutter_down(): s | cmd_pkt
' Decrease shutter
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_SHUTTER
    cmd_pkt.byte[2] := SHUTTER_DN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_shutter_reset(): s | cmd_pkt
' Reset shutter setting
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_SHUTTER
    cmd_pkt.byte[2] := SHUTTER_RES
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_shutter_up(): s | cmd_pkt
' Increase shutter
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_SHUTTER
    cmd_pkt.byte[2] := SHUTTER_UP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_slowshutter_mode(md): s | cmd_pkt
' Set automatic slow shutter mode
'   md:
'       SLSHUT_AUTO ($02):  automatic
'       SLSHUT_MAN ($03):   manual
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_SLSHUT
    cmd_pkt.byte[2] := SLSHUT_AUTO #> md <# SLSHUT_MAN
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_unfreeze_image(): s | cmd_pkt
' Unfreeze the camera image
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_FREEZE
    cmd_pkt.byte[2] := FREEZE_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_whitebalance_mode(md): s | cmd_pkt
' Power on camera
'   wb:
'       WB_AUTO ($00):      automatic
'       WB_INDOOR ($01):    indoor
'       WB_OUTDOOR ($02):   outdoor
'       WB_ONEPUSH ($03):   one push white balance
'       WB_ATW ($04):       auto tracing white balance
'       WB_MANUAL ($05):    manual control
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_WHITEBAL
    cmd_pkt.byte[2] := WB_AUTO #> md <# WB_MANUAL
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_wide_dyn_range_off(): s | cmd_pkt
' Disable wide dynamic range
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_WD
    cmd_pkt.byte[2] := WD_OFF
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_wide_dyn_range_on(): s | cmd_pkt
' Enable wide dynamic range
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_WD
    cmd_pkt.byte[2] := WD_ON
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_stop(): s | cmd_pkt
' Stop a zoom operation
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_STOP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_in = cam_zoom_tele
pub cam_zoom_tele(): s | cmd_pkt
' Zoom in (telephoto)
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_TELE
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_out = cam_zoom_wide
pub cam_zoom_wide(): s | cmd_pkt
' Zoom out (wide)
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_WIDE
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_tele_var(v): s | cmd_pkt
' Zoom in (telephoto)
'   v:  zoom level (0..7) xxx verify
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_TELE_VAR | (0 #> v <# 7)
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_wide_var(v): s | cmd_pkt
' Zoom out (wide)
'   v:  zoom level (0..7) xxx verify
'   Returns:
'       data packet length sent to camera on success
'       negative numbers on failure
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_WIDE_VAR | (0 #> v <# 7)
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub model_id(): v | cmd_pkt
' Read the model ID from the camera
'   Returns:
'        16-bit model ID on success
'       negative numbers on failure
    cmd_pkt.byte[0] := IF_INQ
    cmd_pkt.byte[1] := DEV_TYPE
    v := command(_cam_id, INQ_CMD, @cmd_pkt, 2)
    if ( v < 0 )
        return

    return (_rxbuff[4] << 8) | _rxbuff[5]


pub parse_msg(p_msg): t | b, idx
' Parse a read message
'   Returns: message type
    idx := 0
    repeat
        b := byte[p_msg][idx]
        if ( idx == 0 )
            _last_rcvd_id := (b >> 4)-8
        if ( idx == 1 )
            case b
                NET_CHANGE:
                    _net_change := true
                COMPLETION:
                    t := (getchar() << 4) | getchar()
        idx++
    until (b == TERMINATE)


pub readreg(reg_nr): v | cmd_pkt, r, idx
' Read a camera register
'   reg_nr: register number to read
'   Returns: register value
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := REG_VAL
    cmd_pkt.byte[2] := reg_nr
    v := command(_cam_id, INQ_CMD, @cmd_pkt, 3)
    if ( v < 0 )
        return v

    idx := -1
    repeat
        r := getchar()
        idx++
'        ser[_dbg].printf2(@"[VISCA] idx %d = %02.2x\n\r", idx, r)
        if ( idx < 2 )
            next
        if ( idx == 2 )
            v := r << 4
        if ( idx == 3 )
            v |= r
    until ( r == TERMINATE )


PUB rom_version(): v | cmd_pkt
' Read the ROM version from the camera
'   Returns: ROM version
    cmd_pkt.byte[0] := IF_INQ
    cmd_pkt.byte[1] := DEV_TYPE
    v := command(_cam_id, INQ_CMD, @cmd_pkt, 2)
    if ( v < 0 )
        return

    return (_rxbuff[6] << 8) | _rxbuff[7]


pub set_cam_id(id)
' Set ID of camera to use for subsequent operations
'   id: 1..7 (clamped to range)
    _cam_id := 1 #> id <# 7


pub vendor_id(): v | cmd_pkt
' Read the vendor ID from the camera
'   Returns: 16-bit vendor ID
    cmd_pkt.byte[0] := $00
    cmd_pkt.byte[1] := $02
    v := command(_cam_id, INQ_CMD, @cmd_pkt, 2)
    if ( v < 0 )
        return

    return (_rxbuff[2] << 8) | _rxbuff[3]


pri command(dest_id, cmd_t, p_data, len): s | idx
' Issue a command to the camera
'   dest_id:    camera ID (1..7)
'   cmd_t:      command type
'   p_data:     pointer to parameters/data to write
'   len:        length of parameters
'   Returns:
'       number of bytes sent on success
'       negative numbers on failure
    if ( (dest_id < 1) or (dest_id > 8) )
        abort -1                               ' bad address; must be 1..8

    if ( (len < PAYLD_LEN_MIN) or (len > PAYLD_LEN_MAX) )
        abort -1                               ' bad payload length; must be 1..14

    { cache a copy of the message }
    bytefill(@_buff, 0, MSG_LEN_MAX)
    s := 0
    _buff[s++] := START_BIT | (_src_addr << SRC) | dest_id
    _buff[s++] := cmd_t
    repeat len
        _buff[s++] := byte[p_data++]
    _buff[s++] := TERMINATE

    ser[_dbg].str(@"[VISCA] ")
    ser[_dbg].hexdump_noascii(@_buff, 0, 1, s, s)

    { now actually send it }
    repeat idx from 0 to s-1
        putchar(_buff[idx])

    if ( read_resp() < 0 )
        return -1

    return idx                              ' addr byte + cmd_t + len + terminator

var byte _rxbuff[MSG_LEN_MAX]
pri read_resp(): s | idx, b

    bytefill(@_rxbuff, 0, MSG_LEN_MAX)
    idx := 0
    repeat
        _rxbuff[idx++] := b := getchar()
    until ( b == TERMINATE )
    ser[_dbg].str(@"[VISCA] ")
    ser[_dbg].hexdump(@_rxbuff, 0, 1, idx, idx)

    case _rxbuff[1] & RESPTYPE_MASK
        $40, $50:
            'ser[_dbg].printf1(@"[VISCA] read_resp() ret %02.2x\n\r", _rxbuff[1])
            return 1
        $60:
            'ser[_dbg].printf1(@"[VISCA] read_resp() error; ret %02.2x\n\r", _rxbuff[1])
            return -1


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

