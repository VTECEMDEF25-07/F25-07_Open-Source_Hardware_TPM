import contextlib
import hashlib
import io
import struct
import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from lenovo_hash_panel import NULL_TICKET, SAMPLES, hash_message, measure, run_panel


class HashTransport:
    def __init__(self):
        self.messages = []

    def transact(self, packet, timeout_s):
        tag, size, code, length = struct.unpack(">HIIH", packet[:12])
        assert (tag, size, code) == (0x8001, len(packet), 0x17D)
        assert size == length + 18 and packet[-6:] == bytes.fromhex("000b40000007")
        message = packet[12:12 + length]
        self.messages.append(message)
        return bytes.fromhex("800100000034000000000020") + hashlib.sha256(message).digest() + NULL_TICKET


class HashPanelTests(unittest.TestCase):
    def test_hash_packet_boundaries(self):
        transport = HashTransport()
        for message in (b"", b"abc", bytes(1024)):
            self.assertEqual(hash_message(transport, message), hashlib.sha256(message).digest())
        with self.assertRaises(ValueError):
            hash_message(transport, bytes(1025))
        with self.assertRaises(ValueError):
            hash_message(transport, "abc")

    def test_normal_and_modified_measurements(self):
        transport = HashTransport()
        self.assertTrue(measure(transport, "NORMAL")[2])
        self.assertFalse(measure(transport, "MODIFIED")[2])
        self.assertEqual(transport.messages, list(SAMPLES.values()))

    def test_reject_bad_or_incorrect_fpga_responses(self):
        correct = HashTransport().transact(bytes.fromhex("8001000000150000017d0003616263000b40000007"), 10)
        for bad in (b"", correct[:-1], b"\x80\x02" + correct[2:],
                    correct[:10] + b"\0\x1f" + correct[12:], correct[:-1] + b"\1",
                    correct[:12] + bytes(32) + correct[44:], bytes.fromhex("80010000000a00000100")):
            class BadTransport:
                def transact(self, packet, timeout_s):
                    return bad
            with self.subTest(reply=bad.hex()):
                with self.assertRaises(ValueError):
                    hash_message(BadTransport(), b"abc")

    def test_buttons_drive_spi_digest_display_and_leds(self):
        history, writes = [], []

        class Widget:
            def __init__(self, *args, **kwargs):
                self.config(**kwargs)
            def config(self, **kwargs):
                history.append(kwargs)
            configure = config
            def pack(self, **kwargs):
                pass

        class Root(Widget):
            def __init__(self):
                self.callbacks = []
            def title(self, value):
                pass
            def geometry(self, value):
                pass
            def after(self, delay, callback):
                self.callbacks.append(callback)
            def mainloop(self):
                for _ in range(3):
                    self.callbacks.pop(0)()

        class Panel:
            def __init__(self, *args, **kwargs):
                self.chunks = [b"ignored\nNOR", b"MAL\r\n", b"MODIFIED\n"]
            def read(self, count):
                return self.chunks.pop(0)
            def write(self, value):
                writes.append(value)
                return len(value)
            def close(self):
                pass

        class Executor:
            def __init__(self, **kwargs):
                pass
            def submit(self, function, *args):
                future = Future()
                try:
                    future.set_result(function(*args))
                except Exception as error:
                    future.set_exception(error)
                return future
            def shutdown(self, **kwargs):
                pass

        tk = types.SimpleNamespace(Tk=Root, Label=Widget, Frame=Widget, Button=Widget,
                                   LEFT="left", NORMAL="normal", DISABLED="disabled")
        ports = types.SimpleNamespace(comports=lambda: [])
        serial = types.SimpleNamespace(Serial=Panel, SerialException=OSError)
        transport = HashTransport()
        with patch.dict("sys.modules", {"tkinter": tk, "serial": serial,
                                       "serial.tools": types.SimpleNamespace(list_ports=ports),
                                       "serial.tools.list_ports": ports}):
            with patch("lenovo_hash_panel.ThreadPoolExecutor", Executor):
                with contextlib.redirect_stdout(io.StringIO()):
                    run_panel(transport, "COM5")
        self.assertEqual(transport.messages, [SAMPLES["NORMAL"], SAMPLES["MODIFIED"]])
        self.assertEqual([value for value in writes if value in (b"G", b"R")], [b"G", b"R"])
        self.assertTrue(any(item.get("text") == "Matches original" for item in history))
        self.assertTrue(any(item.get("text") == "Measurement changed" for item in history))
        for message in SAMPLES.values():
            self.assertTrue(any(item.get("text") == "FPGA SHA-256  " + hashlib.sha256(message).hexdigest()
                                for item in history))
        history.clear()
        writes.clear()

        class FailingTransport:
            def transact(self, packet, timeout_s):
                return bytes.fromhex("80010000000a00000100")

        with patch.dict("sys.modules", {"tkinter": tk, "serial": serial,
                                       "serial.tools": types.SimpleNamespace(list_ports=ports),
                                       "serial.tools.list_ports": ports}):
            with patch("lenovo_hash_panel.ThreadPoolExecutor", Executor):
                run_panel(FailingTransport(), "COM5")
        self.assertFalse(any(value in (b"G", b"R") for value in writes))
        self.assertTrue(any(item.get("text", "").startswith("Measurement failed:") for item in history))


if __name__ == "__main__":
    unittest.main()
