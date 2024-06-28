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

    { CAM_ commands }
    CAM_CMD                 = $04
        CAM_PWR             = $00
        CAM_ZOOM            = $07
            ZOOM_STOP       = $00
            ZOOM_TELE       = $02
            ZOOM_WIDE       = $03
            ZOOM_TELE_VAR   = $20
            ZOOM_WIDE_VAR   = $30
        REG_VAL             = $24


pub attach_dbg(optr)
' Attach a debugging output object
    _dbg := optr


pub attach_funcs(p_tx, p_rx)
' Attach to putchar() and getchar() functions
'   p_tx:   pointer to putchar() function
'   p_rx:   pointer to getchar() function
    putchar := p_tx
    getchar := p_rx


pub cam_power(pwr): s | cmd_pkt
' Power on camera
'   id: camera id (1..7)
'   pwr:
'       TRUE (non-zero values): power on
'       FALSE (0): power off
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_PWR
    cmd_pkt.byte[2] := (pwr) ? $02 : $03        ' non-zero? Power on; else power off.
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_stop(): s | cmd_pkt
' Stop a zoom operation
'   id: camera id (1..7)
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_STOP
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_in = cam_zoom_tele
pub cam_zoom_tele(): s | cmd_pkt
' Zoom in (telephoto)
'   id: camera id (1..7)
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_TELE
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_out = cam_zoom_wide
pub cam_zoom_wide(): s | cmd_pkt
' Zoom out (wide)
'   id: camera id (1..7)
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_WIDE
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_tele_var(v): s | cmd_pkt
' Zoom in (telephoto)
'   id: camera id (1..7)
'   v:  zoom level xxx verify
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_TELE_VAR | (0 #> v <# 7)
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub cam_zoom_wide_var(v): s | cmd_pkt
' Zoom out (wide)
'   id: camera id (1..7)
'   v:  zoom level xxx verify
    cmd_pkt.byte[0] := CAM_CMD
    cmd_pkt.byte[1] := CAM_ZOOM
    cmd_pkt.byte[2] := ZOOM_WIDE_VAR | (0 #> v <# 7)
    s := command( _cam_id, CTRL_CMD, @cmd_pkt, 3 )


pub model_id(): v | cmd_pkt
' Read the model ID from the camera
'   Returns: 16-bit model ID
    cmd_pkt.byte[0] := $00
    cmd_pkt.byte[1] := $02
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
    ser[_dbg].hexdump(@_buff, 0, 1, s, s)

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
            ser[_dbg].printf1(@"[VISCA]: read_resp() ret %02.2x\n\r", _rxbuff[1])
            return 1
        $60:
            ser[_dbg].printf1(@"[VISCA]: read_resp() error; ret %02.2x\n\r", _rxbuff[1])
            return -1


