#!/usr/bin/env python3
"""RevD HPS ST7567 display of actual FPGA status snapshots only.

No board access occurs on import. Linux transport uses the interfaces/line offsets
documented in Terasic RevD hps_lcd; it does not configure HPS pinmux or boot Linux.
Input is one exact three-integer JSON snapshot per line, forwarded from the FPGA
status register. Never call this with fabricated customer-CLI step messages.
"""
import argparse
import ctypes
import json
import os
import select
import struct
import sys
import time


# Compact original 5x7 uppercase font, rows encoded left-to-right.
PATTERNS = {
 'A':'01110 10001 10001 11111 10001 10001 10001',
 'B':'11110 10001 10001 11110 10001 10001 11110',
 'C':'01111 10000 10000 10000 10000 10000 01111',
 'D':'11110 10001 10001 10001 10001 10001 11110',
 'E':'11111 10000 10000 11110 10000 10000 11111',
 'F':'11111 10000 10000 11110 10000 10000 10000',
 'G':'01111 10000 10000 10111 10001 10001 01111',
 'H':'10001 10001 10001 11111 10001 10001 10001',
 'I':'11111 00100 00100 00100 00100 00100 11111',
 'J':'00111 00010 00010 00010 10010 10010 01100',
 'K':'10001 10010 10100 11000 10100 10010 10001',
 'L':'10000 10000 10000 10000 10000 10000 11111',
 'M':'10001 11011 10101 10101 10001 10001 10001',
 'N':'10001 11001 10101 10011 10001 10001 10001',
 'O':'01110 10001 10001 10001 10001 10001 01110',
 'P':'11110 10001 10001 11110 10000 10000 10000',
 'Q':'01110 10001 10001 10001 10101 10010 01101',
 'R':'11110 10001 10001 11110 10100 10010 10001',
 'S':'01111 10000 10000 01110 00001 00001 11110',
 'T':'11111 00100 00100 00100 00100 00100 00100',
 'U':'10001 10001 10001 10001 10001 10001 01110',
 'V':'10001 10001 10001 10001 10001 01010 00100',
 'W':'10001 10001 10001 10101 10101 10101 01010',
 'X':'10001 10001 01010 00100 01010 10001 10001',
 'Y':'10001 10001 01010 00100 00100 00100 00100',
 'Z':'11111 00001 00010 00100 01000 10000 11111',
 '0':'01110 10001 10011 10101 11001 10001 01110',
 '1':'00100 01100 00100 00100 00100 00100 01110',
 '2':'01110 10001 00001 00010 00100 01000 11111',
 '3':'11110 00001 00001 01110 00001 00001 11110',
 '4':'00010 00110 01010 10010 11111 00010 00010',
 '5':'11111 10000 10000 11110 00001 00001 11110',
 '6':'01110 10000 10000 11110 10001 10001 01110',
 '7':'11111 00001 00010 00100 01000 01000 01000',
 '8':'01110 10001 10001 01110 10001 10001 01110',
 '9':'01110 10001 10001 01111 00001 00001 01110',
 ' ':'00000 00000 00000 00000 00000 00000 00000',
 '-':'00000 00000 00000 11111 00000 00000 00000',
 '/':'00001 00010 00010 00100 01000 01000 10000',
 ':':'00000 00100 00100 00000 00100 00100 00000',
 '?':'01110 10001 00001 00010 00100 00000 00100',
}
STATES = ('READY', 'STARTUP / PHASE I', 'RNG PREPARE', 'AES256 KEYGEN',
          'RSA KEYGEN', 'WAITING FOR INPUT', 'AES DECRYPT',
          'RSA PRIVATE DECRYPT', 'DONE', 'HARDWARE ERROR')
MODES = ('FRESH UNQUALIFIED', 'TEST ONLY', 'UNAVAILABLE', 'INVALID PROVIDER')


def decode_snapshot(record):
    if not isinstance(record, dict) or set(record) != {'status_word', 'operation_id', 'sequence'}:
        raise ValueError('require exactly status_word, operation_id, sequence')
    for value in record.values():
        if type(value) is not int or not 0 <= value <= 0xffffffff:
            raise ValueError('snapshot fields must be unsigned 32-bit integers')
    word = record['status_word']
    if word >> 24 != 1 or word & 0xff00:
        raise ValueError('unsupported status version or nonzero reserved bits')
    code = word & 15
    if bool(word & 64) != (code >= 9):
        raise ValueError('inconsistent hardware error flag')
    return dict(record, valid=bool(word & 128), code=code,
                detail=(word >> 16) & 255, mode=(word >> 4) & 3)


def status_lines(record=None, *, stale=False, invalid=False):
    if invalid:
        return ['DE25 CRYPTO DEMO', '', 'INVALID HW SNAPSHOT', '', 'NO SUCCESS CLAIM']
    if record is None or not record['valid']:
        return ['DE25 CRYPTO DEMO', '', 'WAIT HW STATUS', '', 'NO ACTIVE SNAPSHOT']
    state_text = STATES[record['code']] if record['code'] < 10 else 'UNKNOWN HW STATE'
    if record['code'] == 8:
        # Lead-approved sticky DONE detail is the actual completed FPGA opcode.
        state_text = {2:'AES DECRYPT DONE',4:'RSA DECRYPT DONE'}.get(record['detail'],state_text)
    return ['DE25 CRYPTO DEMO', MODES[record['mode']], '',
            'STATUS STALE' if stale else state_text,
            f"OP {record['operation_id']:08X}", f"DETAIL {record['detail']:02X}",
            f"SEQ {record['sequence']:08X}", 'LAST HW SNAPSHOT' if stale else 'ACTUAL HW STATUS']


def render(lines):
    if len(lines) > 8 or any(len(line) > 21 for line in lines):
        raise ValueError('text exceeds 128x64 display bounds')
    frame = bytearray(1024)
    for page, line in enumerate(lines):
        for index, ch in enumerate(line):
            rows = PATTERNS.get(ch, PATTERNS['?']).split()
            for col in range(5):
                frame[page*128 + index*6 + col] = sum((rows[y][col] == '1') << y for y in range(7))
    return bytes(frame)


class ST7567:
    """Write-only command/frame layer; backend may be Linux hardware or capture."""
    def __init__(self, transport, sleep=time.sleep):
        self.transport, self.sleep = transport, sleep

    def initialize(self):
        self.transport.backlight(False)
        self.transport.reset(False); self.sleep(0.0625)
        self.transport.reset(True); self.sleep(0.0625)
        # RevD vendor LCD_Lib.c: COM reverse, power, startline, page/column.
        # Keep display off until every DDRAM column has been initialized.
        self.transport.write(False, bytes((0xae, 0xc8, 0x2f, 0x40)))
        self.sleep(0.02)
        for page in range(8):
            self.transport.write(False, bytes((0xb0 | page, 0x00, 0x10)))
            self.transport.write(True, bytes(132))
        self.transport.write(False, b'\xaf')
        self.transport.backlight(True)

    def display(self, frame):
        if len(frame) != 1024:
            raise ValueError('frame must be exactly 128x64 bits')
        for page in range(8):
            self.transport.write(False, bytes((0xb0 | page, 0x00, 0x10)))
            self.transport.write(True, frame[page*128:(page+1)*128])


class LinuxLCD:
    """Existing RevD HPS pinmux required; fail closed if any device is absent."""
    def __init__(self, spi='/dev/spidev0.0', gpiochip='/dev/gpiochip0', speed=500000):
        import fcntl
        self.ioctl = fcntl.ioctl
        self.spi = self.gpio = None
        self.values = bytearray(64)
        # Linux gpio v1 character-device ABI; matches vendor gpio_lib.c.
        class Request(ctypes.Structure):
            _fields_ = [('offsets', ctypes.c_uint32*64), ('flags', ctypes.c_uint32),
                        ('defaults', ctypes.c_ubyte*64), ('consumer', ctypes.c_char*32),
                        ('lines', ctypes.c_uint32), ('fd', ctypes.c_int)]
        assert ctypes.sizeof(Request) == 364
        chip = os.open(gpiochip, os.O_RDONLY | os.O_CLOEXEC)
        try:
            req = Request()
            req.offsets[0], req.offsets[1], req.offsets[2] = 10, 11, 18
            req.flags, req.lines, req.consumer = 2, 3, b'de25-real-hw-status'
            req.defaults[0] = self.values[0] = 1
            self.ioctl(chip, 0xc16cb403, req)
            self.gpio = req.fd
        finally:
            os.close(chip)
        try:
            self.spi = os.open(spi, os.O_RDWR | os.O_CLOEXEC)
            self.ioctl(self.spi, 0x40016b01, struct.pack('B', 0)) # mode0
            self.ioctl(self.spi, 0x40016b02, struct.pack('B', 0)) # MSB-first
            self.ioctl(self.spi, 0x40016b03, struct.pack('B', 8)) # MSB-first default
            self.ioctl(self.spi, 0x40046b04, struct.pack('I', speed))
        except BaseException:
            self.close()
            raise

    def _line(self, index, high):
        self.values[index] = bool(high)
        self.ioctl(self.gpio, 0xc040b409, self.values)

    def reset(self, high): self._line(0, high)
    def backlight(self, high): self._line(2, high)

    def write(self, data_mode, data):
        self._line(1, data_mode)
        if os.write(self.spi, data) != len(data):
            raise OSError('partial LCD SPI transfer; display state unknown')

    def close(self):
        for name in ('spi', 'gpio'):
            fd = getattr(self, name, None)
            if fd is not None:
                os.close(fd)
                setattr(self, name, None)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--spi', default='/dev/spidev0.0')
    p.add_argument('--gpiochip', default='/dev/gpiochip0')
    p.add_argument('--speed', type=int, default=500000)
    p.add_argument('--stale-seconds', type=float, default=2.0)
    args = p.parse_args()
    if not 10000 <= args.speed <= 2500000 or not 0.5 <= args.stale_seconds <= 60:
        p.error('unsafe/unsupported rate or stale threshold')
    backend = LinuxLCD(args.spi, args.gpiochip, args.speed)
    lcd = ST7567(backend)
    last = None; last_at = 0; last_frame = None
    pending = bytearray()
    try:
        lcd.initialize()
        lcd.display(render(status_lines()))
        while True:
            ready, _, _ = select.select([sys.stdin.fileno()], [], [], 0.2)
            invalid = False
            if ready:
                data = os.read(sys.stdin.fileno(), 4096)
                if not data:
                    lcd.display(render(status_lines(last, stale=True)))
                    return
                pending.extend(data)
                if len(pending) > 16384:
                    raise ValueError('oversized status stream')
                while b'\n' in pending:
                    line, _, tail = pending.partition(b'\n'); pending = bytearray(tail)
                    try:
                        last = decode_snapshot(json.loads(line)); last_at = time.monotonic()
                    except (ValueError, TypeError, UnicodeError):
                        last = None; invalid = True
            frame = render(status_lines(last, stale=time.monotonic()-last_at > args.stale_seconds, invalid=invalid))
            if frame != last_frame:
                lcd.display(frame); last_frame = frame
    finally:
        backend.close()


if __name__ == '__main__':
    main()
