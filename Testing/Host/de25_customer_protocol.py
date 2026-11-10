"""Frozen 2026-11-10 vendor v2 customer protocol. No hardware access at import."""
from dataclasses import dataclass
import struct
from de25_customer_crypto import FpgaRsaPublicKey

COMMAND=0x20000101
VERSION=2
STATUS_BASE=0xD40F80
METADATA='>BBBBIIHHIII'
METADATA_BYTES=28


class ProtocolError(RuntimeError): pass


@dataclass(frozen=True)
class Reply:
    opcode:int
    provider:int
    state:int
    request_id:int
    handle:int
    flags:int
    body:bytes


@dataclass(frozen=True)
class Capabilities:
    aes_bits:int
    rsa_bits:int
    max_aes:int
    max_rsa_message:int
    core_hz:int
    status_base:int
    stats_base:int
    features:int


def request(opcode:int,request_id:int,handle:int=0,body:bytes=b'',allow_export:bool=False) -> bytes:
    if opcode not in range(6) or not 0<request_id<2**32 or not 0<=handle<2**32:
        raise ValueError('Invalid customer operation/id/handle')
    if allow_export != (opcode==1):
        raise ValueError('Only AES_GENERATE_EXPORT requires an explicit demo-export flag')
    if opcode in (0,1,3,5) and (handle or body):
        raise ValueError('CAPS/generation/status have no input handle or body')
    prefix=struct.pack('>BBHIII',VERSION,opcode,int(allow_export),request_id,handle,0)
    return struct.pack('>HII',0x8001,10+len(prefix)+len(body),COMMAND)+prefix+body


def parse_reply(raw:bytes,opcode:int,request_id:int,expected_provider:int) -> Reply:
    if len(raw)<10: raise ProtocolError('Incomplete TPM response header')
    tag,size,rc=struct.unpack('>HII',raw[:10])
    if size!=len(raw) or not 10<=size<=4096 or tag!=0x8001:
        raise ProtocolError('Malformed TPM response framing')
    if rc:
        if size!=10: raise ProtocolError('Error response improperly exposes payload')
        raise ProtocolError(f'FPGA operation {opcode} failed: RC 0x{rc:08x}')
    if size<10+METADATA_BYTES: raise ProtocolError('Missing vendor v2 response metadata')
    ver,op,provider,state,ident,handle,capacity,flags,status,cleanup,n=struct.unpack(METADATA,raw[10:38])
    if (ver,op,ident)!=(VERSION,opcode,request_id): raise ProtocolError('Wrong version/opcode/stale operation ID')
    if provider!=expected_provider or provider not in (0,1): raise ProtocolError('FPGA provider changed or mismatched; no fallback')
    if capacity!=1024 or state not in range(10) or flags&~0x3f or flags&4:
        raise ProtocolError('Invalid capacity/status/flags or unsupported entropy qualification')
    if bool(flags&2)!=(provider==1): raise ProtocolError('Provider/test flag mismatch')
    if status or cleanup or flags&8: raise ProtocolError('FPGA operation/cleanup/recovery incomplete')
    if n!=len(raw)-38: raise ProtocolError('Vendor response body length mismatch')
    return Reply(op,provider,state,ident,handle,flags,raw[38:])


def decode_snapshot(raw:bytes,expected_provider:int) -> dict|None:
    if len(raw)!=16: raise ProtocolError('Hardware status snapshot must contain16 bytes')
    before,word,opid,after=struct.unpack('<IIII',raw)
    if before!=after: return None # Caller retries a torn snapshot, never invents state.
    version=(word>>24)&255; detail=(word>>16)&255; reserved=(word>>8)&255
    valid=bool(word&0x80); error=bool(word&0x40); provider=(word>>4)&3; state=word&15
    if not valid: return None
    if version!=1 or reserved or state not in range(10) or provider!=expected_provider or error!=(state==9):
        raise ProtocolError('Invalid actual hardware status snapshot')
    return dict(status_word=word,operation_id=opid,sequence=before,state=state,detail=detail,provider=provider)


class CustomerClient:
    def __init__(self,transport,provider:int=0,recorder=None):
        if provider not in (0,1): raise ValueError('Provider must be explicitly fresh-unqualified or test')
        self.transport=transport; self.provider=provider; self.recorder=recorder; self.next_id=1

    def exchange(self,opcode,handle=0,body=b'',allow_export=False):
        ident=self.next_id; self.next_id+=1
        raw=self.transport.transact(request(opcode,ident,handle,body,allow_export),timeout_s=185)
        reply=parse_reply(bytes(raw),opcode,ident,self.provider)
        if self.recorder:
            # Deliberately do NOT record raw replies: opcode1 contains an authorized secret.
            self.recorder.emit('fpga-completion',f'FPGA operation {opcode} complete; status {reply.state}',
                               opcode=opcode,operation_id=ident,hardware_state=reply.state,
                               handle=reply.handle,body_bytes=len(reply.body),provider=reply.provider)
        return reply

    def startup(self):
        raw=bytes(self.transport.transact(bytes.fromhex('80010000000c000001440000'),timeout_s=185))
        if raw!=bytes.fromhex('80010000000a00000000'): raise ProtocolError('Startup(CLEAR) did not return exact success')

    def capabilities(self):
        r=self.exchange(0)
        if len(r.body)!=24: raise ProtocolError('CAPS body must be24 bytes')
        caps=Capabilities(*struct.unpack('>HHHHIIII',r.body))
        if (caps.aes_bits,caps.rsa_bits,caps.max_aes,caps.max_rsa_message,caps.core_hz)!=(256,2048,1024,240,50000000):
            raise ProtocolError('Customer demo requires the exact AES256/RSA2048/50MHz profile')
        if caps.status_base!=STATUS_BASE or caps.stats_base!=0xD40FA0 or caps.features&7!=7 or caps.features&~7:
            raise ProtocolError('Required export/private-RSA/actual-status capabilities unavailable')
        if r.flags&0x30!=0x30: raise ProtocolError('Demo AES export or FPGA private RSA is disabled by build')
        return caps

    def generate_aes_export(self,allowed:bool):
        if not allowed: raise ValueError('Explicit DEMO-ONLY AES export acknowledgment is required')
        r=self.exchange(1,allow_export=True)
        if len(r.body)!=32 or not r.handle or r.flags&0x11!=0x11:
            raise ProtocolError('AES generation/export was not exactly32 committed authorized bytes')
        return r.handle,bytearray(r.body)

    def decrypt_aes(self,handle:int,iv:bytes,ciphertext:bytes):
        if len(iv)!=16 or len(ciphertext)>1024: raise ValueError('Invalid AES IV/ciphertext length')
        r=self.exchange(2,handle,iv+len(ciphertext).to_bytes(2,'big')+ciphertext)
        if len(r.body)<18 or r.handle!=handle: raise ProtocolError('Malformed AES decrypt response/handle')
        n=int.from_bytes(r.body[:2],'big')
        if n!=len(ciphertext) or len(r.body)!=2+n+16: raise ProtocolError('AES plaintext length mismatch')
        return r.body[2:2+n],r.body[2+n:]

    def generate_rsa_public(self):
        r=self.exchange(3)
        if not r.handle or r.flags&0x21!=0x21 or len(r.body)!=264:
            raise ProtocolError('RSA generation did not commit complete private context/public fields')
        if r.body[:2]!=b'\1\0' or r.body[258:260]!=b'\0\4':
            raise ProtocolError('RSA n/e length mismatch')
        return r.handle,FpgaRsaPublicKey.from_fpga(r.body[2:258],r.body[260:264])

    def decrypt_rsa(self,handle:int,ciphertext:bytes):
        if len(ciphertext)!=256: raise ValueError('RSA2048 ciphertext must contain exactly256 bytes')
        r=self.exchange(4,handle,b'\1\0'+ciphertext)
        if len(r.body)<2 or r.handle!=handle: raise ProtocolError('Malformed RSA decrypt response/handle')
        n=int.from_bytes(r.body[:2],'big')
        if n>240 or len(r.body)!=n+2: raise ProtocolError('RSA plaintext length mismatch')
        return r.body[2:]
