import contextlib
import hashlib
import io
import threading
import unittest
from collections import deque

from de25_button_panel import ButtonController, ButtonPanel, SAMPLES
from de25_customer_console import PublicRecorder
from de25_customer_demo import run_customer_flow
from de25_customer_protocol import CustomerClient
from test_de25_customer_evidence import fixture
from test_de25_customer_protocol import SoftwareBoardModel


class Display:
    def __init__(self):
        self.inputs = deque()
        self.results = []
        self.errors = []
    def poll(self, enqueue):
        while self.inputs:
            enqueue(self.inputs.popleft())
    def queued(self, selection):
        pass
    def measuring(self, message):
        pass
    def result(self, message, digest, matches):
        self.results.append((message, digest, matches))
    def error(self, error):
        self.errors.append(error)


class Board(SoftwareBoardModel):
    def __init__(self):
        super().__init__()
        self.active = False
        self.owner_thread = threading.get_ident()
    def transact(self, packet, timeout_s=185):
        if self.active or threading.get_ident() != self.owner_thread:
            raise AssertionError("Concurrent transaction or second SPI owner")
        self.active = True
        try:
            return super().transact(packet, timeout_s)
        finally:
            self.active = False


class ButtonTests(unittest.TestCase):
    def test_both_buttons_use_real_hash_packets_and_preserve_status(self):
        board = Board()
        display = Display()
        display.inputs.extend(["ignored", "NORMAL", "MODIFIED"])
        callback = []
        board.status_callback = callback.append
        original_transact, original_poll = board.transact, board.poll_status
        controller = ButtonController(board, display)
        controller.pump()
        board.poll_status(force=True)
        self.assertEqual([item[2] for item in display.results], [True, False])
        self.assertEqual([packet[12:-6] for packet in board.calls], list(SAMPLES.values()))
        for message, digest, _ in display.results:
            self.assertEqual(digest, hashlib.sha256(message).digest())
        self.assertTrue(callback)
        controller.close()
        self.assertEqual(board.transact, original_transact)
        self.assertEqual(board.poll_status, original_poll)
        self.assertFalse(display.errors)

    def test_buttons_queue_during_crypto_and_complete_full_existing_flow(self):
        board = Board()
        recorder = PublicRecorder()

        class DuringCrypto(Display):
            def __init__(self):
                super().__init__()
                self.queued_states = set()
            def poll(self, enqueue):
                if board.active and board.state in (3, 4) and board.state not in self.queued_states:
                    self.queued_states.add(board.state)
                    enqueue("NORMAL" if board.state == 3 else "MODIFIED")

        display = DuringCrypto()

        class Panel:
            def attach(self, transport):
                self.controller = ButtonController(transport, display, recorder)

        panel = Panel()
        with contextlib.redirect_stdout(io.StringIO()):
            summary = run_customer_flow(CustomerClient(board, 0, recorder), recorder,
                                        fixture(), True, auto=True, message="Expo guest",
                                        rsa_message="RSA guest", button_panel=panel)
        panel.controller.close()
        self.assertTrue(summary["aes"]["plaintext_match"])
        self.assertTrue(summary["rsa"]["plaintext_match"])
        self.assertTrue(summary["hash"]["match"])
        self.assertEqual([item[2] for item in display.results], [True, False])
        self.assertEqual([packet[11] for packet in board.calls
                          if int.from_bytes(packet[6:10], "big") == 0x20000101], [0, 1, 2, 3, 4])
        self.assertEqual(len([event for event in recorder.events if event["event"] == "button-hash"]), 2)
        self.assertFalse(display.errors)

    def test_bad_digest_reports_error_and_timeout_propagates(self):
        board = Board()
        board.bad_hash = True
        display = Display()
        controller = ButtonController(board, display)
        controller.enqueue("NORMAL")
        controller.pump()
        self.assertFalse(display.results)
        self.assertEqual(len(display.errors), 1)
        controller.close()

        class TimedOut:
            def transact(self, *args, **kwargs):
                raise TimeoutError("SPI timeout")
            def poll_status(self, **kwargs):
                return None

        controller = ButtonController(TimedOut(), display)
        controller.enqueue("NORMAL")
        with self.assertRaises(TimeoutError):
            controller.pump()
        controller.close()

    def test_fragmented_serial_lines_and_led_commands(self):
        class Root:
            def update_idletasks(self):
                pass
            def update(self):
                pass
        class Serial:
            def __init__(self):
                self.chunks = deque([b"NOR", b"MAL\r\nMOD", b"IFIED\n"])
                self.writes = []
            def read(self, count):
                return self.chunks.popleft()
            def write(self, value):
                self.writes.append(value)
                return len(value)
        panel = ButtonPanel.__new__(ButtonPanel)
        panel.closed = False
        panel.root = Root()
        panel.serial = Serial()
        panel.serial_error = (OSError,)
        panel.events = deque()
        panel.buffer = bytearray()
        selections = []
        for _ in range(3):
            panel.poll(selections.append)
        self.assertEqual(selections, ["NORMAL", "MODIFIED"])
        panel.send_led(b"G")
        panel.send_led(b"R")
        self.assertEqual(panel.serial.writes, [b"G", b"R"])


if __name__ == "__main__":
    unittest.main()
