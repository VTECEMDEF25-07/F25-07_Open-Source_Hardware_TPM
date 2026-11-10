"""Public customer-demo events and exact-byte display; no synthetic FPGA progress."""
from datetime import datetime,timezone
from pathlib import Path
import json,time

HARDWARE_STATES={0:'READY',1:'STARTUP / PHASE I',2:'RNG PREPARE',3:'AES KEYGEN',
                 4:'RSA KEYGEN',5:'WAITING FOR INPUT',6:'AES DECRYPT',
                 7:'RSA PRIVATE DECRYPT',8:'DONE',9:'ERROR'}
SECRET_FIELDS={'key','aes_key','private_key','d','p','q','raw_response','raw_transaction'}


class PublicRecorder:
    """Recording preserves actual host events; call actual_status only with readback data."""
    def __init__(self,output_dir: Path|None=None):
        self.started=time.monotonic(); self.events=[]; self.lines=[]; self.output_dir=output_dir
        if output_dir: output_dir.mkdir(parents=True,exist_ok=True)

    def emit(self,event: str,text: str,**fields):
        if SECRET_FIELDS.intersection(fields):
            raise ValueError('Secret/raw-key fields cannot enter the public recording')
        row=dict(utc=datetime.now(timezone.utc).isoformat(),elapsed_s=time.monotonic()-self.started,
                 event=event,text=text,**fields)
        self.events.append(row)
        line=f"[{row['elapsed_s']:08.3f}s] {text}"; self.lines.append(line)
        print(line,flush=True)
        self.flush()
        return row

    def actual_status(self,state: int,operation_id: int,detail: int,provider: int):
        if state not in HARDWARE_STATES or not 0<=detail<=255 or provider not in (0,1):
            raise ValueError('Invalid returned hardware status descriptor')
        return self.emit('hardware-status',f'FPGA status: {HARDWARE_STATES[state]} (operation {operation_id}, detail {detail})',
                         hardware_state=state,operation_id=operation_id,detail=detail,provider=provider,
                         source='actual FPGA status reply; not a display-glass observation')

    def flush(self):
        if self.output_dir:
            (self.output_dir/'events.json').write_text(json.dumps(self.events,indent=2),encoding='utf-8')
            (self.output_dir/'stdout.txt').write_text('\n'.join(self.lines)+'\n',encoding='utf-8')


def show_bytes(value: bytes) -> str:
    """Exact text display, escaping control characters that could alter the terminal."""
    return json.dumps(value.decode('utf-8'),ensure_ascii=False)


def input_message(label: str,maximum: int,auto_text: str|None=None) -> bytes:
    from de25_customer_crypto import utf8_message
    if auto_text is not None:
        return utf8_message(auto_text,maximum)
    while True:
        text=input(f'{label} (UTF-8, max {maximum} bytes): ')
        try: return utf8_message(text,maximum)
        except ValueError as exc: print(str(exc),flush=True)
