import contextlib
import hashlib
import io
import json
import struct
import types
import unittest
from concurrent.futures import Future
from unittest.mock import patch

from lenovo_hash_panel import NULL_TICKET, SAMPLES, decrypt_message, hash_message, measure, run_panel


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
    def test_gui_crypto_operations_share_transport_and_check_results(self):
        from de25_customer_protocol import CustomerClient
        from test_de25_customer_protocol import SoftwareBoardModel
        board = SoftwareBoardModel()
        client = CustomerClient(board)
        client.startup()
        client.capabilities()
        text = "Expo test"
        for mode in ("AES", "RSA"):
            plain, ciphertext, digest, elapsed = decrypt_message(client, mode, text, lambda msg: None)
            self.assertEqual(plain, text)
            self.assertNotEqual(ciphertext, text.encode())
            if mode == "RSA":
                self.assertEqual(digest, hashlib.sha256(text.encode()).hexdigest())
        self.assertTrue(measure(board, "NORMAL")[2])
        self.assertFalse(measure(board, "MODIFIED")[2])
        for mode in ("AES", "RSA"):
            setattr(board, "bad_" + mode.lower(), True)
            with self.assertRaisesRegex(ValueError, "plaintext differs"):
                decrypt_message(client, mode, text, lambda msg: None)

    def test_hash_recovers_when_the_first_startup_leaves_fpga_uninitialized(self):
        message = b"BOOT: START APP"
        commands = []
        class ResetBoard(HashTransport):
            def transact(self, packet, timeout_s):
                commands.append(int.from_bytes(packet[6:10], "big"))
                if len(commands) in (1, 3, 4):
                    return bytes.fromhex("80010000000a00000100")
                if commands[-1] == 0x144:
                    return bytes.fromhex("80010000000a00000000")
                return super().transact(packet, timeout_s)
        self.assertEqual(hash_message(ResetBoard(), message), hashlib.sha256(message).digest())
        self.assertEqual(commands, [0x17D, 0x144, 0x17D, 0x144, 0x17D])

    def test_startup_recovery_is_bounded_and_rejects_malformed_replies(self):
        from unittest.mock import Mock
        initialize = bytes.fromhex("80010000000a00000100")
        transport = Mock()
        transport.transact.return_value = initialize
        with self.assertRaisesRegex(ValueError, "Hash returned 0x00000100"):
            hash_message(transport, b"abc")
        self.assertEqual(transport.transact.call_count, 5)
        transport.transact.reset_mock()
        transport.transact.side_effect = [initialize, bytes(10)]
        with self.assertRaisesRegex(ValueError, "Startup response"):
            hash_message(transport, b"abc")
        self.assertEqual(transport.transact.call_count, 2)

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
                    correct[:12] + bytes(32) + correct[44:], bytes.fromhex("80010000000a00000101")):
            class BadTransport:
                def transact(self, packet, timeout_s):
                    return bad
            with self.subTest(reply=bad.hex()):
                with self.assertRaises(ValueError):
                    hash_message(BadTransport(), b"abc")

    def test_buttons_drive_spi_digest_display_and_leds(self):
        # Load native crypto bindings before the temporary GUI module map.
        from cryptography.hazmat.primitives import ciphers

        history, writes = [], []
        crypto_clicks = []
        trace = []

        class Widget:
            def __init__(self, *args, **kwargs):
                self.config(**kwargs)
            def config(self, **kwargs):
                history.append(kwargs)
            configure = config
            def pack(self, **kwargs):
                pass
            def insert(self, index, value):
                self.value = value
            def get(self):
                return self.value

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
                self.callbacks.pop(0)()
                next(item["command"] for item in history if item.get("text") == "Raw UART")()
                for _ in range(2):
                    self.callbacks.pop(0)()
                for title in crypto_clicks:
                    next(item["command"] for item in history
                         if "command" in item and item["text"].startswith(title))()
                    self.callbacks.pop(0)()

        class Panel:
            def __init__(self, *args, **kwargs):
                self.chunks = [b"ignored\nNOR", b"MAL\r\n", b"MODIFIED\n"]
            def read(self, count):
                return self.chunks.pop(0) if self.chunks else b""
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

        class Monitor(Widget):
            def title(self, value):
                pass
            def protocol(self, name, callback):
                pass
            def withdraw(self):
                pass
            def see(self, position):
                pass
            def insert(self, position, value):
                trace.append(value)

        tk = types.SimpleNamespace(Tk=Root, Label=Widget, Frame=Widget, Button=Widget, Entry=Widget,
                                   Toplevel=Monitor, RIGHT="right", LEFT="left", NORMAL="normal", DISABLED="disabled")
        self.enterContext(patch.dict("sys.modules", {"tkinter.scrolledtext": types.SimpleNamespace(ScrolledText=Monitor)}))
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
        self.assertIn(r"RX  69 67 6e 6f 72 65 64 0a 4e 4f 52  |ignored\nNOR|", "".join(trace))
        self.assertIn(r"RX  4d 41 4c 0d 0a  |MAL\r\n|", "".join(trace))
        self.assertRegex("".join(trace), r"\d\d:\d\d:\d\d\.\d{3}  TX  47  \|G\|")
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

        from de25_customer_protocol import CustomerClient
        from test_de25_customer_protocol import SoftwareBoardModel
        board = SoftwareBoardModel()
        client = CustomerClient(board)
        history.clear()
        writes.clear()
        crypto_clicks.extend(("AES-256", "RSA-2048"))
        log = io.StringIO()
        with patch.dict("sys.modules", {"tkinter": tk, "serial": serial,
                                       "serial.tools": types.SimpleNamespace(list_ports=ports),
                                       "serial.tools.list_ports": ports}):
            with patch("lenovo_hash_panel.ThreadPoolExecutor", Executor):
                with contextlib.redirect_stdout(io.StringIO()):
                    run_panel(board, "COM9", client, log)
        events = [json.loads(line) for line in log.getvalue().splitlines()]
        self.assertEqual([e["selection"] for e in events if e.get("source") == "nucleo"],
                         ["NORMAL", "MODIFIED"])
        self.assertEqual([(e["algorithm"], e["plaintext"]) for e in events
                          if e["event"] == "crypto_pass"], [("AES", "Hello Lenovo"), ("RSA", "Hello Lenovo")])
        self.assertFalse(any(e["event"] == "failed" for e in events))


if __name__ == "__main__":
    unittest.main()
