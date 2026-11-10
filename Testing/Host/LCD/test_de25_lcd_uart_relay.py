import builtins
import contextlib
import io
import json
from pathlib import Path
import runpy
import threading
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch
import de25_lcd_uart_relay as relay

RECORD = dict(status_word=0x01000080, operation_id=17, sequence=42)
LINE = (json.dumps(RECORD) + '\n').encode()


def inventory(**kw):
    values = dict(device='COM7', serial_number='TRWZCK53B', description='USB Serial Port (COM7)', hwid='USB SER=TRWZCK53B')
    values.update(kw)
    return SimpleNamespace(**values)


class FakeSerial:
    def __init__(self, **kw):
        self.kw = kw
        self.writes = []
        self.reads = []
        self.opened = self.closed = False
        self.short_write = self.fail_read = self.fail_write = False
        self.close_event = None

    def open(self):
        assert self.kw['port'] is None and self.port == 'COM7'
        assert self.dtr is False and self.rts is False
        self.opened = True

    def close(self):
        if self.close_event:
            self.close_event.wait(1)
        self.closed = True

    def write(self, data):
        if self.fail_write:
            raise OSError('fake serial disconnect during write')
        self.writes.append(data)
        return len(data) - int(self.short_write)

    def read(self, count):
        assert count == 256
        if self.fail_read:
            raise OSError('fake serial disconnect during read')
        if self.reads:
            return self.reads.pop(0)
        time.sleep(.001)
        return b''


class Tests(unittest.TestCase):
    def transport(self):
        serial = FakeSerial()
        events = []
        return serial, relay.Transport(serial, lambda event, **kw: events.append((event, kw))), events

    def test_import_and_help_never_import_or_open_serial(self):
        original = builtins.__import__
        def checked(name, *a, **kw):
            if name == 'serial' or name.startswith('serial.'):
                raise AssertionError('serial must be lazy')
            return original(name, *a, **kw)
        with patch('builtins.__import__', checked):
            runpy.run_path(str(Path(relay.__file__)), run_name='import_safety')
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as caught:
                relay.main(['--help'])
            self.assertEqual(caught.exception.code, 0)

    def test_wrong_port_fails_before_serial_import(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            relay.main(['--port', 'COM5'])
        for port in ['COM5', 'COM8', r'\\.\COM5', '/dev/ttyUSB0', '']:
            with self.subTest(port=port), self.assertRaises(ValueError):
                relay.verify_identity(port, [inventory()])

    def test_expected_device_identity(self):
        got = relay.verify_identity('com7', [inventory()])
        self.assertEqual(got['identity'], 'SERIAL_MATCH')
        got = relay.verify_identity('COM7', [inventory(serial_number=None)])
        self.assertEqual(got['serial'], relay.EXPECTED_SERIAL)
        got = relay.verify_identity('COM7', [inventory(serial_number=None, hwid='')])
        self.assertEqual(got['identity'], 'DESCRIPTOR_ONLY_SERIAL_UNAVAILABLE')
        for infos in [[], [inventory(), inventory()], [inventory(serial_number='OTHER')],
                      [inventory(hwid='USB SER=OTHER')], [inventory(description='FT232H SPI')],
                      [inventory(serial_number=None, description='', hwid='')]]:
            with self.subTest(infos=infos), self.assertRaises(ValueError):
                relay.verify_identity('COM7', infos)
        with self.assertRaises(ValueError):
            relay.verify_identity('COM7', [inventory()], expected_description='DIFFERENT DEVICE')

    def test_wire_schema_all_actual_states_providers(self):
        for mode in range(4):
            for code in range(16):
                r = dict(status_word=0x01000080 | mode << 4 | code | (64 if code >= 9 else 0),
                         operation_id=0xffffffff, sequence=42)
                line = (json.dumps(r) + '\n').encode()
                self.assertEqual(json.loads(relay.parse_record(line)), r)

    def test_reject_invalid_records(self):
        cases = [b'{}\n', b'null\n', LINE[:-1], b'\0\n', b'x' * 257 + b'\n', b'\xff\n',
                 b'{"status_word":16777344,"operation_id":17,"operation_id":42}\n']
        for key, value in [('status_word', 0), ('status_word', 0x01000180),
                           ('status_word', 0x010000c0), ('sequence', True),
                           ('sequence', -1), ('sequence', 2**32), ('sequence', 1.5), ('extra', 1)]:
            r = dict(RECORD)
            r[key] = value
            cases.append((json.dumps(r) + '\n').encode())
        for line in cases:
            with self.subTest(line=line), self.assertRaises((ValueError, UnicodeError)):
                relay.parse_record(line)

    def test_open_configuration_before_open(self):
        seen = []
        def factory(**kw):
            obj = FakeSerial(**kw)
            seen.append(obj)
            return obj
        serial = relay.open_uart(factory, 'COM7')
        self.assertTrue(serial.opened)
        self.assertEqual(serial.kw, dict(port=None, baudrate=115200, bytesize=8, parity='N', stopbits=1,
                                        timeout=.05, write_timeout=.25, xonxoff=False,
                                        rtscts=False, dsrdtr=False))
        self.assertEqual(len(seen), 1)

    def test_actual_duplicate_heartbeats_are_preserved(self):
        serial, transport, events = self.transport()
        relay.relay_stream(io.BytesIO(LINE + LINE), transport, drain_seconds=.01)
        self.assertEqual(len(serial.writes), 2)
        self.assertEqual(serial.writes[0], serial.writes[1])
        self.assertTrue(all(json.loads(p) == RECORD for p in serial.writes))
        self.assertEqual(sum(event == 'snapshot_sent' for event, kw in events), 2)

    def test_bad_input_sends_no_snapshot(self):
        serial, transport, events = self.transport()
        with self.assertRaises(ValueError):
            relay.relay_stream(io.BytesIO(b'{}\n'), transport, drain_seconds=.01)
        self.assertEqual(serial.writes, [])

    def test_bounded_capture_only_retains_boot_and_ack(self):
        serial, transport, events = self.transport()
        serial.reads = [b'DE25 LCD OCRAM UART1\r\nFRAME_', b'SENT 0000002A\r\n']
        relay.relay_stream(None, transport, capture_seconds=.02)
        self.assertEqual(serial.writes, [])
        raw = b''.join(bytes.fromhex(kw['hex']) for event, kw in events if event == 'uart_rx')
        self.assertEqual(raw, b'DE25 LCD OCRAM UART1\r\nFRAME_SENT 0000002A\r\n')
        ack = next(kw for event, kw in events if event == 'frame_sent_ack')
        self.assertEqual(ack, dict(sequence=42, glass_verified=False))

    def test_uart_without_newline_stays_bounded(self):
        serial, transport, events = self.transport()
        serial.reads = [b'A' * 256, b'B' * 256, b'\nFRAME_SENT 0000002A\r\n']
        for _ in range(3):
            transport.pump()
            self.assertLessEqual(len(transport.partial), 255)
        self.assertEqual(sum(event == 'uart_line_overflow' for event, kw in events), 1)
        self.assertEqual(sum(event == 'frame_sent_ack' for event, kw in events), 1)

    def test_overflow_cannot_manufacture_a_framed_ack(self):
        serial, transport, events = self.transport()
        serial.reads = [b'A' * 256, b'FRAME_SENT 0000002A\r\n']
        transport.pump()
        transport.pump()
        self.assertFalse(any(event == 'frame_sent_ack' for event, kw in events))

    def test_serial_failures_are_surfaced(self):
        for flag in ['short_write', 'fail_write', 'fail_read']:
            serial, transport, events = self.transport()
            setattr(serial, flag, True)
            with self.subTest(flag=flag), self.assertRaises(OSError):
                transport.pump() if flag == 'fail_read' else transport.send(LINE)

    def test_shutdown_is_bounded(self):
        serial, transport, events = self.transport()
        serial.close_event = threading.Event()
        started = time.monotonic()
        try:
            with self.assertRaises(OSError):
                transport.close(timeout=.01)
            self.assertLess(time.monotonic() - started, .2)
        finally:
            serial.close_event.set()
        serial, transport, events = self.transport()
        transport.close()
        self.assertTrue(serial.closed)

    def test_blocked_stdin_does_not_block_serial_failure_exit(self):
        event = threading.Event()
        class Input:
            def readline(self, size):
                event.wait(1)
                return b''
        serial, transport, events = self.transport()
        serial.fail_read = True
        started = time.monotonic()
        try:
            with self.assertRaises(OSError):
                relay.relay_stream(Input(), transport)
            self.assertLess(time.monotonic() - started, .3)
        finally:
            event.set()


if __name__ == '__main__':
    unittest.main()
