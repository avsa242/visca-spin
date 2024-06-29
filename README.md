# visca-spin
------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for Sony's VISCA camera protocol

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* VISCA controller side
* Modular: can be "attached" to virtually any I/O driver
* Adjust camera image: zoom, focus (manual, automatic), aperture, blue/red gain, brightness, gain, iris, gamma, shutter, white balance
* Additional settings: autoexposure, backlight compensation, exposure compensation, IR correction/compensation, IR cut, noise reduction
* Enable/disable features: on-screen display, image mute, wide dynamic-range
* Read vendor, model IDs, firmware version


## Requirements

P1/SPIN1:
* spin-standard-library
* An I/O driver that provides a single-character transmit routine with one parameter, and a single-character receive routine with one return value (e.g., `putchar()` and `getchar()` from `com.serial.terminal.ansi.spin`)

P2/SPIN2:
* p2-spin-standard-library


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | FTBFS                 |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Not yet implemented   |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | Not yet implemented   |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Hardware compatibility

* Tested with KTC XBC-KZ10


## Limitations

* Very early in development - may malfunction, or outright fail to build
* Draft version - API shouldn't be considered stable yet

