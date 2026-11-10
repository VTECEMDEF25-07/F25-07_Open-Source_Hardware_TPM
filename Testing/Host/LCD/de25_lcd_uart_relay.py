#!/usr/bin/env python3
"""Forward only real FPGA snapshots to the explicitly selected DE25 UART.

No serial import, enumeration or device opening occurs on import/help. The lead
alone runs this against hardware. UART FRAME_SENT is never optical glass proof.
"""
import argparse
import json
import queue
import re
import sys
import threading
import time
from de25_lcd import decode_snapshot

MAX_RECORD = 256
EXPECTED_SERIAL = 'TRWZCK53B'


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON field')
        result[key] = value
    return result


def parse_record(line):
    if not isinstance(line, bytes) or not line.endswith(b'\n') or len(line) > MAX_RECORD or b'\0' in line:
        raise ValueError('require a complete ASCII JSON line of at most256 bytes')
    record = json.loads(line.decode('ascii'), object_pairs_hook=unique_object)
    decode_snapshot(record)  # Same uint32/version/reserved/error/provider semantics.
    return (json.dumps(record, separators=(',', ':'), ensure_ascii=True) + '\n').encode('ascii')


def verify_identity(port, ports, expected_serial=EXPECTED_SERIAL, expected_description=None):
    # Frozen Windows board binding; never auto-select another UART or SPI COM5.
    if port.upper() != 'COM7':
        raise ValueError('only explicit COM7 is permitted; COM5 is the SPI adapter')
    matches = [p for p in ports if str(p.device).upper() == 'COM7']
    if len(matches) != 1:
        raise ValueError('COM7 must be present exactly once in serial inventory')
    info = matches[0]
    serial = getattr(info, 'serial_number', None)
    description = str(getattr(info, 'description', '') or '')
    hwid = str(getattr(info, 'hwid', '') or '')
    reported = re.search(r'\bSER=([^\s]+)', hwid)
    if not serial and reported:
        serial = reported.group(1)
    if serial and serial != expected_serial:
        raise ValueError('COM7 serial identity does not match the expected DE25 UART')
    if reported and reported.group(1) != expected_serial:
        raise ValueError('COM7 hardware serial identity conflicts with the DE25 UART')
    if re.search(r'FT232H|MPSSE|\bSPI\b', description, re.I):
        raise ValueError('COM7 descriptor identifies an SPI adapter')
    if expected_description and expected_description.casefold() not in description.casefold():
        raise ValueError('COM7 descriptor does not match the explicitly expected descriptor')
    if not serial and not description:
        raise ValueError('COM7 has neither serial identity nor a descriptor to inspect')
    return dict(port='COM7', serial=serial, description=description,
                identity='SERIAL_MATCH' if serial else 'DESCRIPTOR_ONLY_SERIAL_UNAVAILABLE')


def open_uart(factory, port):
    serial = factory(port=None, baudrate=115200, bytesize=8, parity='N', stopbits=1,
                     timeout=.05, write_timeout=.25, xonxoff=False,
                     rtscts=False, dsrdtr=False)
    # Configure desired modem-line states before opening, then never toggle them.
    # A driver-level opening transient cannot be excluded by this software test.
    serial.dtr = False
    serial.rts = False
    serial.port = port
    try:
        serial.open()
    except BaseException:
        Transport(serial, lambda *a, **k: None).close()
        raise
    return serial


class Transport:
    def __init__(self, serial, emit):
        self.serial, self.emit = serial, emit
        self.partial = bytearray()
        self.discard_line = False

    def send(self, payload):
        # Validate here too so callers/tests cannot bypass the same wire contract.
        payload = parse_record(payload)
        if self.serial.write(payload) != len(payload):
            raise OSError('short UART write; tuple delivery is unknown')
        self.emit('snapshot_sent', json=json.loads(payload))

    def pump(self):
        raw = self.serial.read(256)
        if not raw:
            return
        if len(raw) > 256:
            raise OSError('serial backend exceeded the bounded read request')
        self.emit('uart_rx', hex=raw.hex(), ascii=raw.decode('ascii', errors='backslashreplace'))
        for byte in raw:
            if self.discard_line:
                if byte == 10:
                    self.discard_line = False
                continue
            self.partial.append(byte)
            if byte == 10:
                line = bytes(self.partial)
                match = re.fullmatch(rb'FRAME_SENT ([0-9A-F]{8})\r?\n', line)
                if match:
                    self.emit('frame_sent_ack', sequence=int(match.group(1), 16), glass_verified=False)
                self.partial.clear()
            elif len(self.partial) == 256:
                self.emit('uart_line_overflow', limit=256)
                self.partial.clear()
                self.discard_line = True

    def close(self, timeout=.3):
        outcome = []
        def finish():
            try:
                self.serial.close()
            except BaseException as exc:
                outcome.append(exc)
        worker = threading.Thread(target=finish, daemon=True)
        worker.start()
        worker.join(timeout)
        if worker.is_alive():
            raise OSError('UART close exceeded its shutdown budget')
        if outcome:
            raise OSError('UART close failed') from outcome[0]


def relay_stream(stream, transport, *, capture_seconds=None, drain_seconds=.5):
    pending = queue.Queue(maxsize=4)
    stop = threading.Event()
    eof = object()
    def enqueue(item):
        while not stop.is_set():
            try:
                pending.put(item, timeout=.05)
                return
            except queue.Full:
                pass
    def read_stdin():
        try:
            while not stop.is_set():
                line = stream.readline(MAX_RECORD + 1)
                if not line:
                    enqueue(eof)
                    return
                enqueue(parse_record(line))
        except BaseException as exc:
            enqueue(exc)
    worker = None
    deadline = time.monotonic() + capture_seconds if capture_seconds is not None else None
    if capture_seconds is None:
        worker = threading.Thread(target=read_stdin, daemon=True)
        worker.start()
    try:
        while deadline is None or time.monotonic() < deadline:
            if deadline is None:
                try:
                    item = pending.get(timeout=.01)
                except queue.Empty:
                    item = None
                if item is eof:
                    deadline = time.monotonic() + drain_seconds
                elif isinstance(item, BaseException):
                    raise ValueError('invalid or failed snapshot input') from item
                elif item is not None:
                    transport.send(item)  # Duplicates remain real heartbeat writes.
            transport.pump()
    finally:
        stop.set()
        if worker:
            worker.join(.1)  # A blocked stdin read is daemonized, never an unbounded join.


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='explicit COM7; no automatic selection')
    parser.add_argument('--expected-serial', default=EXPECTED_SERIAL)
    parser.add_argument('--expected-description', help='optional exact expected descriptor substring')
    parser.add_argument('--capture-only', action='store_true', help='bounded UART boot log; sends no snapshots')
    parser.add_argument('--capture-seconds', type=float, default=5)
    args = parser.parse_args(argv)
    if args.port.upper() != 'COM7':
        parser.error('only COM7 is permitted; never use SPI adapter COM5')
    if not 0 < args.capture_seconds <= 30:
        parser.error('--capture-seconds must be in (0,30]')
    def emit(event, **fields):
        print(json.dumps(dict(event=event, monotonic=time.monotonic(), **fields), ensure_ascii=True), flush=True)
    transport = None
    result = 0
    try:
        import serial
        from serial.tools import list_ports
        identity = verify_identity(args.port, list(list_ports.comports()),
                                   args.expected_serial, args.expected_description)
        emit('uart_identity', **identity)
        transport = Transport(open_uart(serial.Serial, 'COM7'), emit)
        emit('uart_open', baudrate=115200, mode='8N1', flow_control=False)
        relay_stream(sys.stdin.buffer, transport,
                     capture_seconds=args.capture_seconds if args.capture_only else None)
    except (Exception, KeyboardInterrupt) as exc:
        emit('relay_failure', kind=type(exc).__name__, message=str(exc))
        result = 2
    finally:
        if transport:
            try:
                transport.close()
            except Exception as exc:
                emit('relay_failure', kind=type(exc).__name__, message=str(exc))
                result = 2
    return result


if __name__ == '__main__':
    raise SystemExit(main())
