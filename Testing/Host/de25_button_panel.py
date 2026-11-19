"""Nucleo Hash panel sharing the archive customer's main-thread SPI session."""
import hashlib
import hmac
import time
from collections import deque

from de25_customer_fpga_hash import hash_request, parse_hash_response

SAMPLES = {"NORMAL": b"BOOT: START APP", "MODIFIED": b"BOOT: START BPP"}


class ButtonController:
    """Queue button work and execute Hash only between complete TPM commands."""
    def __init__(self, transport, display, recorder=None):
        self.transport = transport
        self.display = display
        self.recorder = recorder
        self.pending = deque()
        self.depth = 0
        self.measuring = False
        self.closed = False
        self.original_transact = transport.transact
        self.original_poll = transport.poll_status
        transport.transact = self.transact
        transport.poll_status = self.poll_status

    def enqueue(self, selection):
        if selection in SAMPLES and not self.closed:
            self.pending.append(selection)
            self.display.queued(selection)

    def transact(self, *args, **kwargs):
        self.depth += 1
        try:
            reply = self.original_transact(*args, **kwargs)
        finally:
            self.depth -= 1
        self.pump()
        return reply

    def poll_status(self, *args, **kwargs):
        snapshot = self.original_poll(*args, **kwargs)
        self.pump()
        return snapshot

    def pump(self):
        if self.closed:
            return
        self.display.poll(self.enqueue)
        if self.closed or self.depth or self.measuring or not self.pending:
            return
        selection = self.pending.popleft()
        message = SAMPLES[selection]
        self.measuring = True
        try:
            self.display.measuring(message)
            reply = bytes(self.transact(hash_request(message), timeout_s=185))
            digest = parse_hash_response(reply)
            if not hmac.compare_digest(digest, hashlib.sha256(message).digest()):
                raise ValueError("FPGA digest differs from the reference for this sample")
            matches = hmac.compare_digest(digest, hashlib.sha256(SAMPLES["NORMAL"]).digest())
            self.display.result(message, digest, matches)
            if self.recorder is not None:
                self.recorder.emit("button-hash", "BUTTON HASH: " + selection + " " + digest.hex(),
                                   selection=selection, sample_hex=message.hex(),
                                   fpga_digest_hex=digest.hex(), matches_original=matches)
        except (TimeoutError, OSError) as error:
            self.display.error(error)
            raise
        except Exception as error:
            self.display.error(error)
        finally:
            self.measuring = False

    def close(self):
        if not self.closed:
            self.closed = True
            self.pending.clear()
            self.transport.transact = self.original_transact
            self.transport.poll_status = self.original_poll


class ButtonPanel:
    def __init__(self, port=None, recorder=None):
        import tkinter as tk
        from serial import Serial, SerialException
        from serial.tools import list_ports

        self.controller = None
        self.recorder = recorder
        self.closed = False
        self.serial = None
        self.buffer = bytearray()
        self.events = deque()
        self.serial_error = (SerialException, OSError)
        self.root = tk.Tk()
        self.root.title("DE25 FPGA Hash — Expo buttons")
        self.root.geometry("920x490")
        self.root.configure(bg="#142030")
        self.root.protocol("WM_DELETE_WINDOW", self.close)

        def label(text, size):
            widget = tk.Label(self.root, text=text, font=("Segoe UI", size),
                              bg="#142030", fg="white", wraplength=880)
            widget.pack(pady=7)
            return widget

        label("Can you spot a changed bootloader?", 24)
        label("Type AES/RSA messages in the terminal. Press buttons to measure the boot sample.", 12)
        self.sample = label("Waiting for TPM Startup", 21)
        label("Original SHA-256  " + hashlib.sha256(SAMPLES["NORMAL"]).hexdigest(), 11)
        self.digest = label("FPGA SHA-256  —", 11)
        self.verdict = label("", 19)
        self.status = label("", 11)
        controls = tk.Frame(self.root, bg="#142030")
        controls.pack(pady=8)
        for title, selection in (("Normal Boot", "NORMAL"), ("Change One Byte", "MODIFIED")):
            tk.Button(controls, text=title, font=("Segoe UI", 12),
                      command=lambda value=selection: self.events.append(value)).pack(side=tk.LEFT, padx=8)
        candidates = [item.device for item in list_ports.comports()
                      if (item.vid, item.pid) == (0x0483, 0x374B)]
        selected = port or (candidates[0] if len(candidates) == 1 else None)
        try:
            if selected:
                self.serial = Serial(selected, 115200, timeout=0, write_timeout=0.2)
                self.send_led(b"-")
                self.status.config(text=f"Nucleo connected on {selected}")
            else:
                self.status.config(text="Use --button-port COMx for the Nucleo, or press an on-screen button.")
        except self.serial_error as error:
            self.status.config(text=f"Nucleo unavailable: {error}. On-screen buttons are available.")

    def attach(self, transport):
        self.controller = ButtonController(transport, self, self.recorder)
        self.sample.config(text="Press either button to hash the boot sample on the FPGA")
        self.controller.pump()

    def send_led(self, value):
        if self.serial is not None:
            try:
                if self.serial.write(value) != len(value):
                    raise OSError("Incomplete LED command")
            except self.serial_error as error:
                self.serial.close()
                self.serial = None
                self.status.config(text=f"Nucleo disconnected: {error}. Use the on-screen buttons.")

    def poll(self, enqueue):
        if self.closed:
            return
        self.root.update_idletasks()
        self.root.update()
        if self.closed:
            return
        if self.serial is not None:
            try:
                self.buffer.extend(self.serial.read(256))
                while b"\n" in self.buffer:
                    line, _, rest = self.buffer.partition(b"\n")
                    self.buffer[:] = rest
                    self.events.append(line.strip().decode("ascii", errors="replace"))
                if len(self.buffer) > 256:
                    self.buffer.clear()
            except self.serial_error as error:
                self.serial.close()
                self.serial = None
                self.status.config(text=f"Nucleo disconnected: {error}. Use the on-screen buttons.")
        while self.events:
            enqueue(self.events.popleft())

    def queued(self, selection):
        self.verdict.config(text="Hash queued — waiting for the current FPGA command", fg="white")
        self.send_led(b"-")

    def measuring(self, message):
        if not self.closed:
            self.sample.config(text=message.decode("ascii"))
            self.digest.config(text="FPGA SHA-256  …")
            self.verdict.config(text="Measuring on FPGA…", fg="white")

    def result(self, message, digest, matches):
        if not self.closed:
            self.digest.config(text="FPGA SHA-256  " + digest.hex())
            self.verdict.config(text="Matches original" if matches else "Measurement changed",
                                fg="#73e2ae" if matches else "#ff8b8b")
            self.send_led(b"G" if matches else b"R")

    def error(self, error):
        if not self.closed:
            self.digest.config(text="FPGA SHA-256  unavailable")
            self.verdict.config(text=f"Measurement failed: {error}", fg="#ff8b8b")
            self.send_led(b"-")

    def run(self):
        if self.closed:
            return
        print("AES/RSA flow finished. Hash buttons remain active; close the Hash window to exit.", flush=True)
        while not self.closed:
            self.controller.poll_status(force=True)
            time.sleep(0.03)

    def close(self):
        if not self.closed:
            self.closed = True
            if self.controller is not None:
                self.controller.close()
            self.send_led(b"-")
            if self.serial is not None:
                self.serial.close()
                self.serial = None
            self.root.destroy()
