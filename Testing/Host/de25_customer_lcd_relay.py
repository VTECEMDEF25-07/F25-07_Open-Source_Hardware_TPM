"""Bounded relay of actual FPGA snapshots to the LCD owner's validated HPS command.

DE25_LCD_COMMAND_JSON is an explicit argv JSON list, normally the hardware lead's
validated SSH command running the LCD service. No shell and no connection at
import. This relays actual status only; pipe success is not physical glass proof.
"""
from pathlib import Path
import json,os,queue,subprocess,threading


class Relay:
    def __init__(self,command:list[str],log_path:Path|None=None):
        if not isinstance(command,list) or not command or not all(isinstance(x,str) and x for x in command):
            raise ValueError('LCD command must be an explicit nonempty argv list')
        self.log=None
        if log_path:
            log_path.parent.mkdir(parents=True,exist_ok=True); self.log=log_path.open('ab')
        self.process=subprocess.Popen(command,stdin=subprocess.PIPE,
            stdout=self.log or subprocess.DEVNULL,stderr=self.log or subprocess.DEVNULL,
            text=True,encoding='utf-8',bufsize=1,shell=False,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        self.pending=queue.Queue(maxsize=1); self.stopping=threading.Event(); self.error=None
        self.worker=threading.Thread(target=self._write,daemon=True); self.worker.start()

    def __call__(self,snapshot:dict):
        if set(snapshot)!= {'status_word','operation_id','sequence'}:
            raise ValueError('LCD service accepts exactly the three actual hardware fields')
        if any(type(v)is not int or not 0<=v<=0xffffffff for v in snapshot.values()):
            raise ValueError('LCD snapshot fields must be uint32 integers')
        if self.error or self.process.poll() is not None:
            raise RuntimeError(f'LCD status relay is unavailable: {self.error or self.process.returncode}')
        payload=json.dumps(snapshot,separators=(',',':'))+'\n'
        try: self.pending.put_nowait(payload)
        except queue.Full:
            # Keep the latest ACTUAL tuple; never manufacture a transition or block SPI.
            try: self.pending.get_nowait()
            except queue.Empty: pass
            self.pending.put_nowait(payload)

    def _write(self):
        try:
            while not self.stopping.is_set() or not self.pending.empty():
                try: payload=self.pending.get(timeout=.1)
                except queue.Empty: continue
                self.process.stdin.write(payload); self.process.stdin.flush()
        except BaseException as exc: self.error=exc

    def close(self):
        self.stopping.set(); self.worker.join(timeout=.5)
        if not self.worker.is_alive():
            try: self.process.stdin.close()
            except (OSError,BrokenPipeError): pass
        try: self.process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try: self.process.wait(timeout=1)
            except subprocess.TimeoutExpired: self.process.kill(); self.process.wait(timeout=1)
        self.worker.join(timeout=.2)
        if self.log: self.log.close()


def factory():
    command=json.loads(os.environ.get('DE25_LCD_COMMAND_JSON','[]'))
    log=os.environ.get('DE25_LCD_RELAY_LOG')
    return Relay(command,Path(log) if log else None)
