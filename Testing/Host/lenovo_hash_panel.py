"""Breadboard button demonstration using the FPGA's standard TPM2_Hash command."""
import hashlib
import hmac
import json
from datetime import datetime, timezone
import os
import queue
import struct
import time
from collections import deque
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


def decrypt_message(client, mode, text, progress):
    from de25_customer_crypto import aes_encrypt_on_laptop, expected_cfb_final_iv, utf8_message

    plaintext = utf8_message(text, 1024 if mode == "AES" else 240)
    started = time.monotonic()
    if mode == "AES":
        progress("Generating disposable AES-256 key on FPGA…")
        handle, key = client.generate_aes_export(allowed=True)
        try:
            iv = os.urandom(16)
            ciphertext = aes_encrypt_on_laptop(bytes(key), iv, plaintext)
        finally:
            key[:] = bytes(len(key))
        progress("Laptop encrypted the message. FPGA is decrypting…")
        result, final_iv = client.decrypt_aes(handle, iv, ciphertext)
        if final_iv != expected_cfb_final_iv(ciphertext, iv):
            raise ValueError("FPGA returned an incorrect final AES IV")
    elif mode == "RSA":
        progress("Generating a fresh RSA-2048 key pair on the FPGA…")
        handle, public = client.generate_rsa_public()
        ciphertext = public.encrypt_on_laptop(plaintext)
        progress("Laptop encrypted with the public key. FPGA is decrypting…")
        result = client.decrypt_rsa(handle, ciphertext)
    else:
        raise ValueError("Unknown decryption mode")
    if result != plaintext:
        raise ValueError("FPGA plaintext differs from the original message")
    digest = None
    if mode == "RSA":
        progress("Checking SHA-256 of the FPGA-returned RSA plaintext…")
        digest = hash_message(client.transport, result).hex()
    return result.decode("utf-8"), ciphertext, digest, time.monotonic() - started


def run_panel(transport, port=None, client=None, event_log=None):
    import tkinter as tk
    from serial import Serial, SerialException
    from serial.tools import list_ports

    candidates = [item.device for item in list_ports.comports()
                  if (item.vid, item.pid) == (0x0483, 0x374B)]
    selected_port = port or (candidates[0] if len(candidates) == 1 else None)
    root = tk.Tk()
    root.title("Lenovo TPM demo")
    root.geometry("900x680" if client else "900x480")
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
    operation = None
    progress = queue.SimpleQueue()
    waiting = deque(maxlen=8)
    uart_history = deque(maxlen=500)
    uart_window = None
    uart_text = None

    def trace_uart(direction, data):
        if not data:
            return
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        ascii_text = ascii(bytes(data))[2:-1]
        line = f"{timestamp}  {direction}  {data.hex(' ')}  |{ascii_text}|\n"
        if uart_text is not None:
            uart_text.configure(state="normal")
            if len(uart_history) == uart_history.maxlen:
                uart_text.delete("1.0", "2.0")
            uart_text.insert("end", line)
            uart_text.see("end")
            uart_text.configure(state="disabled")
        uart_history.append(line)

    def open_uart():
        nonlocal uart_window, uart_text
        if uart_window is not None:
            uart_window.deiconify()
            uart_window.lift()
            return
        from tkinter.scrolledtext import ScrolledText
        uart_window = tk.Toplevel(root)
        uart_window.title(f"Raw UART · {selected_port or 'No Nucleo port'} · 115200")
        uart_text = ScrolledText(uart_window, width=85, height=18, font=("Consolas", 10))
        uart_text.pack(fill="both", expand=True)
        uart_text.insert("end", "".join(uart_history))
        uart_text.see("end")
        uart_text.configure(state="disabled")
        uart_window.protocol("WM_DELETE_WINDOW", uart_window.withdraw)

    def report(event, **fields):
        if event_log is not None:
            event_log.write(json.dumps(dict(time=datetime.now(timezone.utc).isoformat(),
                                            event=event, **fields)) + "\n")
            event_log.flush()

    def disconnect(error):
        nonlocal panel
        panel.close()
        panel = None
        status.config(text=f"Nucleo disconnected: {error}. Use the on-screen buttons.")

    def send_led(value):
        if panel:
            try:
                count = panel.write(value)
                trace_uart("TX", value[:count])
                if count != len(value):
                    raise SerialException("Incomplete LED command")
            except (SerialException, OSError) as error:
                disconnect(error)

    def start(selection, source="screen"):
        nonlocal future, operation
        if future is not None:
            if len(waiting) < waiting.maxlen:
                waiting.append((selection, source))
            return
        operation = "SHA"
        report("sha_start", selection=selection, source=source)
        sample.config(text=SAMPLES[selection].decode("ascii"))
        actual.config(text="FPGA SHA-256  …")
        verdict.config(text="Measuring on FPGA…", fg="white")
        send_led(b"-")
        for button in buttons:
            button.config(state=tk.DISABLED)
        future = executor.submit(measure, transport, selection)

    def start_crypto(mode):
        nonlocal future, operation
        if future is not None:
            return
        operation = mode
        report("crypto_start", algorithm=mode)
        for button in buttons:
            button.config(state=tk.DISABLED)
        actual.config(text="")
        sample.config(text=mode + " decryption")
        verdict.config(text="Starting…", fg="white")
        future = executor.submit(decrypt_message, client, mode, entry.get(), progress.put)

    def poll():
        nonlocal future
        if panel:
            try:
                chunk = panel.read(256)
                trace_uart("RX", chunk)
                pending.extend(chunk)
                while b"\n" in pending:
                    line, _, rest = pending.partition(b"\n")
                    pending[:] = rest
                    selection = line.strip().decode("ascii", errors="replace")
                    if selection in SAMPLES:
                        start(selection, "nucleo")
                if len(pending) > 256:
                    pending.clear()
            except (SerialException, OSError) as error:
                disconnect(error)
        while not progress.empty():
            verdict.config(text=progress.get_nowait(), fg="white")
        if future is not None and future.done():
            try:
                if operation in ("AES", "RSA"):
                    plaintext, encrypted, digest, elapsed = future.result()
                    report("crypto_pass", algorithm=operation, plaintext=plaintext, ciphertext_hex=encrypted.hex(), plaintext_sha256=digest, elapsed_s=elapsed)
                    actual.config(text="Laptop ciphertext  " + encrypted.hex()[:96])
                    sample.config(text="FPGA returned  " + plaintext[:126] + ("…" if len(plaintext) > 126 else ""))
                    verdict.config(text=f"{operation} plaintext verified in {elapsed:.1f} s", fg="#73e2ae")
                else:
                    message, digest, matches = future.result()
                    actual.config(text="FPGA SHA-256  " + digest.hex())
                    verdict.config(text="Matches original" if matches else "Measurement changed",
                                   fg="#73e2ae" if matches else "#ff8b8b")
                    send_led(b"G" if matches else b"R")
                    report("sha_pass", message=message.decode(), digest=digest.hex(), matches_original=matches)
                    print(f"{message!r} FPGA SHA-256 {digest.hex()} matches_original={matches}")
            except Exception as error:
                report("failed", operation=operation, error=str(error))
                actual.config(text=f"FPGA {operation} result unavailable")
                verdict.config(text=f"Measurement failed: {error}", fg="#ff8b8b")
                send_led(b"-")
            future = None
            for button in buttons:
                button.config(state=tk.NORMAL)
            if waiting:
                start(*waiting.popleft())
        root.after(30, poll)

    controls = tk.Frame(root, bg="#142030")
    controls.pack(pady=8)
    tk.Button(controls, text="Raw UART", command=open_uart,
              font=("Segoe UI", 12)).pack(side=tk.RIGHT, padx=8)
    buttons = []
    for title, selection in (("Normal Boot", "NORMAL"), ("Change One Byte", "MODIFIED")):
        button = tk.Button(controls, text=title, command=lambda key=selection: start(key),
                           font=("Segoe UI", 12))
        button.pack(side=tk.LEFT, padx=8)
        buttons.append(button)
    if client is not None:
        label("Message to encrypt on the laptop and decrypt on the FPGA", 14)
        entry = tk.Entry(root, width=60, font=("Segoe UI", 13))
        entry.insert(0, "Hello Lenovo")
        entry.pack(pady=5)
        crypto_controls = tk.Frame(root, bg="#142030")
        crypto_controls.pack(pady=6)
        for mode, title in (("AES", "AES-256 · export demo key and decrypt"),
                            ("RSA", "RSA-2048 · generate key and decrypt")):
            button = tk.Button(crypto_controls, text=title,
                               command=lambda m=mode: start_crypto(m), font=("Segoe UI", 12))
            button.pack(side=tk.LEFT, padx=6)
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
        uart_text = None
        executor.shutdown(wait=True)
        if panel:
            send_led(b"-")
        if panel:
            panel.close()

def main():
    import argparse
    from tkinter import messagebox
    from de25_customer_protocol import CustomerClient
    from de25_customer_transport import factory

    parser = argparse.ArgumentParser(description="Laptop-controlled DE25 SHA, AES and RSA demo")
    parser.add_argument("--port", help="Nucleo serial port (automatically detected by default)")
    parser.add_argument("--log", help="New JSON lines evidence file")
    args = parser.parse_args()
    transport = None
    log = None
    try:
        if args.log:
            log = open(args.log, "x", encoding="utf-8")
        transport = factory()
        client = CustomerClient(transport)
        client.startup()
        client.capabilities()
        run_panel(transport, args.port, client, log)
    except Exception as error:
        messagebox.showerror("DE25 demo", str(error))
        raise
    finally:
        if transport is not None:
            transport.close()
        if log is not None:
            log.close()


if __name__ == "__main__":
    main()
