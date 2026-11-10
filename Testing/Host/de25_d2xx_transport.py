"""Windows-only named FT232H transport. No driver changes or FPGA programming.

Use only after the exact bitstream passes timing. Default100kHz, mode0, verified
even-row wiring, serial FTA6H280. Factory acquires a local hardware mutex and
resets the TPM (all volatile objects are destroyed). It never opens DE25's UART.
Integration hardware owner alone runs this module; --detect is read-only.
"""
from __future__ import annotations
import ctypes as c
import json
import os
import struct
import time

SERIAL=b"FTA6H280"
U32=c.c_uint32
P=c.c_void_p


def driver():
    if os.name!="nt":raise RuntimeError("This transport requires Windows D2XX")
    d=c.WinDLL(r"C:\Windows\System32\ftd2xx.dll")
    signatures={"FT_CreateDeviceInfoList":[c.POINTER(U32)],
        "FT_GetDeviceInfoDetail":[U32,c.POINTER(U32),c.POINTER(U32),c.POINTER(U32),c.POINTER(U32),P,P,c.POINTER(P)],
        "FT_OpenEx":[P,U32,c.POINTER(P)],"FT_Close":[P],"FT_ResetDevice":[P],
        "FT_SetUSBParameters":[P,U32,U32],"FT_SetChars":[P,c.c_ubyte,c.c_ubyte,c.c_ubyte,c.c_ubyte],
        "FT_SetTimeouts":[P,U32,U32],"FT_SetLatencyTimer":[P,c.c_ubyte],
        "FT_SetBitMode":[P,c.c_ubyte,c.c_ubyte],"FT_Purge":[P,U32],
        "FT_Write":[P,P,U32,c.POINTER(U32)],"FT_Read":[P,P,U32,c.POINTER(U32)]}
    for name,args in signatures.items():
        fn=getattr(d,name);fn.argtypes=args;fn.restype=U32
    return d


def check(rc):
    if rc:raise OSError(f"D2XX status {rc}")


def detect():
    d=driver();n=U32();check(d.FT_CreateDeviceInfoList(c.byref(n)));rows=[]
    for i in range(n.value):
        flags,kind,ident,loc=U32(),U32(),U32(),U32();sn=c.create_string_buffer(16);desc=c.create_string_buffer(64);h=P()
        check(d.FT_GetDeviceInfoDetail(i,c.byref(flags),c.byref(kind),c.byref(ident),c.byref(loc),sn,desc,c.byref(h)))
        rows.append(dict(serial=sn.value.decode(),description=desc.value.decode(),id=hex(ident.value),flags=flags.value,type=kind.value))
    return rows


class Transport:
    def __init__(self,hz=100000):
        if hz not in (100000,1000000):raise ValueError("Only100kHz/1MHz acceptance steps are enabled")
        self.d=driver();self.h=P();self.mutex=None;self.closed=False
        k=c.WinDLL("kernel32",use_last_error=True)
        k.CreateMutexW.argtypes=[P,c.c_bool,c.c_wchar_p];k.CreateMutexW.restype=P
        k.WaitForSingleObject.argtypes=[P,U32];k.WaitForSingleObject.restype=U32
        k.ReleaseMutex.argtypes=[P];k.CloseHandle.argtypes=[P]
        self.k=k;self.mutex=k.CreateMutexW(None,False,"Local\\CodexDE25Hardware")
        if not self.mutex:raise c.WinError(c.get_last_error())
        acquired=k.WaitForSingleObject(self.mutex,0)
        if acquired not in (0,0x80):
            k.CloseHandle(self.mutex);self.mutex=None
            raise RuntimeError("DE25 hardware lock busy; no device opened")
        try:
            matches=[x for x in detect() if x["serial"]==SERIAL.decode()]
            if len(matches)!=1 or matches[0]["id"]!="0x4036014":
                raise RuntimeError(f"Expected exactly named FT232H {SERIAL.decode()}; detected {detect()}")
            sn=c.create_string_buffer(SERIAL);check(self.d.FT_OpenEx(c.cast(sn,P),1,c.byref(self.h)))
            check(self.d.FT_ResetDevice(self.h))
            check(self.d.FT_SetUSBParameters(self.h,65536,65536))
            check(self.d.FT_SetChars(self.h,0,0,0,0));check(self.d.FT_SetTimeouts(self.h,500,500))
            check(self.d.FT_SetLatencyTimer(self.h,2));check(self.d.FT_SetBitMode(self.h,0,0))
            check(self.d.FT_SetBitMode(self.h,0x1b,2));time.sleep(.05)
            check(self.d.FT_Purge(self.h,3));self._write(b"\xaa\x87")
            if self._read(2)!=b"\xfa\xaa":raise RuntimeError("MPSSE synchronization failed")
            divider=30000000//hz-1;self.hz=30000000//(divider+1)
            #60MHz MPSSE base, no adaptive/three-phase/loopback. GPIO: SCK0,
            #MOSI1, MISO2 input, CS3, grey reset4. Remaining bits inputs.
            self._write(bytes([0x8a,0x97,0x8d,0x85,0x86,divider&255,divider>>8,0x80,0x18,0x1b,0x82,0,0]))
            self._gpio(0x08);time.sleep(.05);self._gpio(0x18);time.sleep(.25)
        except BaseException:
            self.close();raise

    def _write(self,data):
        b=c.create_string_buffer(bytes(data));n=U32()
        check(self.d.FT_Write(self.h,c.cast(b,P),len(data),c.byref(n)))
        if n.value!=len(data):raise IOError("Short MPSSE write")

    def _read(self,n):
        out=bytearray();deadline=time.monotonic()+2
        while len(out)<n:
            buf=c.create_string_buffer(n-len(out));got=U32()
            check(self.d.FT_Read(self.h,c.cast(buf,P),len(buf),c.byref(got)))
            out.extend(buf.raw[:got.value])
            if time.monotonic()>deadline:raise TimeoutError("MPSSE read timeout")
        return bytes(out)

    def _gpio(self,value):self._write(bytes([0x80,value,0x1b]))

    def _exchange(self,data):
        if not 1<=len(data)<=65536:raise ValueError("MPSSE transfer size")
        n=len(data)-1;self._write(bytes([0x31,n&255,n>>8])+bytes(data)+b"\x87")
        return self._read(len(data))

    def _transfer(self,read,addr,payload):
        n=payload if read else len(payload)
        if not 1<=n<=64:raise ValueError("TPM SPI frame must contain1..64 bytes")
        self._gpio(0x10)
        try:
            ready=self._exchange(bytes([(0xc0 if read else 0x40)|(n-1),0xd4,addr>>8,addr&255]))[-1]
            waits=0
            while not ready&1 and waits<40:
                ready=self._exchange(b"\0" if read else payload[:1])[0];waits+=1
            if not ready&1:raise TimeoutError("TPM SPI ready timeout")
            if read:return self._exchange(bytes(n))
            # Inherited serializer consumes first write byte while returning
            #the ready indication if the command needed a readiness byte.
            remaining=payload[1:] if waits else payload
            if remaining:self._exchange(remaining)
            return b""
        finally:self._gpio(0x18)

    def _write_reg(self,addr,value):self._transfer(False,addr,bytes([value]))
    def _read_reg(self,addr):return self._transfer(True,addr,1)[0]

    def transact(self,packet,timeout_s=185):
        packet=bytes(packet)
        if len(packet)<10 or len(packet)>4096 or int.from_bytes(packet[2:6],"big")!=len(packet):
            raise ValueError("Complete bounded TPM command required")
        deadline=time.monotonic()+timeout_s
        self._write_reg(0,2)
        if self._read_reg(0)!=0xa1:raise RuntimeError("Locality0 was not granted")
        self._write_reg(0x18,0x40);self._write_reg(0x18,0x40)
        while not self._read_reg(0x18)&0x40:
            if time.monotonic()>deadline:raise TimeoutError("commandReady deadline")
            time.sleep(.001)
        for i in range(0,len(packet),64):self._transfer(False,0x24,packet[i:i+64])
        self._write_reg(0x18,0x20)
        while True:
            status=self._read_reg(0x18)
            if status!=0xff and status&0x10:break
            if time.monotonic()>deadline:raise TimeoutError("command execution deadline; discard incomplete response and reset")
            time.sleep(.001)
        reply=self._transfer(True,0x24,10);size=struct.unpack(">I",reply[2:6])[0]
        if not 10<=size<=4096:raise IOError(f"Invalid TPM response size {size}")
        while len(reply)<size:reply+=self._transfer(True,0x24,min(64,size-len(reply)))
        return reply

    def close(self):
        if self.closed:return
        self.closed=True
        if self.h.value:
            try:self._gpio(0x18);self.d.FT_SetBitMode(self.h,0,0)
            finally:self.d.FT_Close(self.h);self.h=P()
        if self.mutex:
            self.k.ReleaseMutex(self.mutex);self.k.CloseHandle(self.mutex);self.mutex=None


def factory():return Transport(int(os.environ.get("DE25_SPI_HZ","100000")))

if __name__=="__main__":print(json.dumps(detect(),indent=2))
