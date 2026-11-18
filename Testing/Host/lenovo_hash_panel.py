"""Breadboard button demonstration using the FPGA's standard TPM2_Hash command."""
import hashlib
import hmac
import struct
from concurrent.futures import ThreadPoolExecutor

SAMPLES = {"NORMAL": b"BOOT: START APP", "MODIFIED": b"BOOT: START BPP"}
NULL_TICKET = bytes.fromhex("8024400000070000")


def hash_message(transport, message):
    if not isinstance(message, bytes) or len(message) > 1024:
        raise ValueError("Hash accepts at most 1024 message bytes")
    body = struct.pack(">H", len(message)) + message + struct.pack(">HI", 0x000B, 0x40000007)
    packet = struct.pack(">HII", 0x8001, 10 + len(body), 0x17D) + body
    reply = bytes(transport.transact(packet, timeout_s=10))
    if len(reply) < 10:
        raise ValueError("Incomplete FPGA Hash response")
    tag, size, code = struct.unpack(">HII", reply[:10])
    if tag != 0x8001 or size != len(reply):
        raise ValueError("Malformed FPGA Hash response header")
    if code:
        raise ValueError(f"TPM2_Hash returned 0x{code:08x}")
    if size != 52 or reply[10:12] != b"\0\x20" or reply[44:] != NULL_TICKET:
        raise ValueError("Malformed FPGA digest or validation ticket")
    digest = reply[12:44]
    if not hmac.compare_digest(digest, hashlib.sha256(message).digest()):
        raise ValueError("FPGA digest differs from the laptop reference for this message")
    return digest


def measure(transport, selection):
    message = SAMPLES[selection]
    digest = hash_message(transport, message)
    matches = hmac.compare_digest(digest, hashlib.sha256(SAMPLES["NORMAL"]).digest())
    return message, digest, matches


def run_panel(transport, port=None):
    import tkinter as tk
    from serial import Serial, SerialException
    from serial.tools import list_ports

    candidates = [item.device for item in list_ports.comports()
                  if (item.vid, item.pid) == (0x0483, 0x374B)]
    selected_port = port or (candidates[0] if len(candidates) == 1 else None)
    root = tk.Tk()
    root.title("FPGA SHA-256 measurement")
    root.geometry("900x480")
    root.configure(bg="#142030")

    def label(text, size):
        widget = tk.Label(root, text=text, font=("Segoe UI", size),
                          bg="#142030", fg="white", wraplength=860)
        widget.pack(pady=7)
        return widget

    label("Can you spot a changed bootloader?", 24)
    label("SPI → Phase One execution engine → FPGA SHA-256", 13)
    sample = label("Press either breadboard button", 22)
    label("Original SHA-256  " + hashlib.sha256(SAMPLES["NORMAL"]).hexdigest(), 11)
    actual = label("FPGA SHA-256  —", 11)
    verdict = label("", 20)
    status = label("", 11)
    panel = None
    pending = bytearray()
    executor = ThreadPoolExecutor(max_workers=1)
    future = None

    def disconnect(error):
        nonlocal panel
        panel.close()
        panel = None
        status.config(text=f"Nucleo disconnected: {error}. Use the on-screen buttons.")

    def send_led(value):
        if panel:
            try:
                if panel.write(value) != len(value):
                    raise SerialException("Incomplete LED command")
            except (SerialException, OSError) as error:
                disconnect(error)

    def start(selection):
        nonlocal future
        if future is not None:
            return
        sample.config(text=SAMPLES[selection].decode("ascii"))
        actual.config(text="FPGA SHA-256  …")
        verdict.config(text="Measuring on FPGA…", fg="white")
        send_led(b"-")
        for button in buttons:
            button.config(state=tk.DISABLED)
        future = executor.submit(measure, transport, selection)

    def poll():
        nonlocal future
        if panel:
            try:
                pending.extend(panel.read(256))
                while b"\n" in pending:
                    line, _, rest = pending.partition(b"\n")
                    pending[:] = rest
                    selection = line.strip().decode("ascii", errors="replace")
                    if selection in SAMPLES:
                        start(selection)
                if len(pending) > 256:
                    pending.clear()
            except (SerialException, OSError) as error:
                disconnect(error)
        if future is not None and future.done():
            try:
                message, digest, matches = future.result()
                actual.config(text="FPGA SHA-256  " + digest.hex())
                verdict.config(text="Matches original" if matches else "Measurement changed",
                               fg="#73e2ae" if matches else "#ff8b8b")
                send_led(b"G" if matches else b"R")
                print(f"{message!r} FPGA SHA-256 {digest.hex()} matches_original={matches}")
            except Exception as error:
                actual.config(text="FPGA SHA-256  unavailable")
                verdict.config(text=f"Measurement failed: {error}", fg="#ff8b8b")
                send_led(b"-")
            future = None
            for button in buttons:
                button.config(state=tk.NORMAL)
        root.after(30, poll)

    controls = tk.Frame(root, bg="#142030")
    controls.pack(pady=8)
    buttons = []
    for title, selection in (("Normal Boot", "NORMAL"), ("Change One Byte", "MODIFIED")):
        button = tk.Button(controls, text=title, command=lambda key=selection: start(key),
                           font=("Segoe UI", 12))
        button.pack(side=tk.LEFT, padx=8)
        buttons.append(button)
    try:
        if selected_port:
            panel = Serial(selected_port, 115200, timeout=0, write_timeout=0.2)
            send_led(b"-")
            status.config(text=f"Nucleo connected on {selected_port}")
        else:
            status.config(text="Connect the Nucleo or use --port COMx. On-screen buttons are available.")
    except (SerialException, OSError) as error:
        status.config(text=f"Panel connection unavailable: {error}. Use the on-screen buttons.")
    try:
        root.after(30, poll)
        root.mainloop()
    finally:
        executor.shutdown(wait=True)
        if panel:
            send_led(b"-")
        if panel:
            panel.close()
