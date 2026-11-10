"""Lead-operated D2XX transport with actual FPGA status polling during long commands.

Inherits named hardware mutex/reset/serial checks unchanged. No FPGA programming.
No hardware is opened until factory/Transport is explicitly called.
"""
import os,struct,time
from de25_d2xx_transport import Transport as BaselineTransport
from de25_customer_protocol import STATUS_BASE,decode_snapshot


class Transport(BaselineTransport):
    def __init__(self,hz=100000):
        self.status_callback=None; self.expected_provider=0; self.last_poll=0
        super().__init__(hz)

    def poll_status(self,force=False):
        if self.status_callback is None or (not force and time.monotonic()-self.last_poll<.25): return
        self.last_poll=time.monotonic()
        for _ in range(5):
            raw=self._transfer(True,STATUS_BASE&0xffff,16)
            snapshot=decode_snapshot(raw,self.expected_provider)
            if snapshot is not None:
                self.status_callback(snapshot)
                return snapshot
        # A reset/torn/invalid snapshot is not replaced by an assumed host state.
        return None

    def transact(self,packet,timeout_s=185):
        packet=bytes(packet)
        if len(packet)<10 or len(packet)>4096 or int.from_bytes(packet[2:6],'big')!=len(packet):
            raise ValueError('Complete bounded TPM command required')
        deadline=time.monotonic()+timeout_s
        self._write_reg(0,2)
        if self._read_reg(0)!=0xa1: raise RuntimeError('Locality0 was not granted')
        self._write_reg(0x18,0x40); self._write_reg(0x18,0x40)
        while not self._read_reg(0x18)&0x40:
            if time.monotonic()>deadline: raise TimeoutError('commandReady deadline')
            self.poll_status(); time.sleep(.001)
        for i in range(0,len(packet),64): self._transfer(False,0x24,packet[i:i+64])
        self._write_reg(0x18,0x20)
        while True:
            status=self._read_reg(0x18)
            if status!=0xff and status&0x10: break
            if time.monotonic()>deadline: raise TimeoutError('FPGA command deadline; discard incomplete reply and reset')
            self.poll_status(); time.sleep(.001)
        reply=self._transfer(True,0x24,10); size=struct.unpack('>I',reply[2:6])[0]
        if not 10<=size<=4096: raise IOError(f'Invalid TPM response size {size}')
        while len(reply)<size: reply+=self._transfer(True,0x24,min(64,size-len(reply)))
        self.poll_status(force=True)
        return reply


def factory(): return Transport(int(os.environ.get('DE25_SPI_HZ','100000')))
