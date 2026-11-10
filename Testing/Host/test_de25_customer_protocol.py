"""SOFTWARE-ONLY vendor protocol board model. Never a hardware PASS artifact.

Private fixture computation below tests the client; no private computation or
host-generated RSA key is used by the real customer client.
"""
from pathlib import Path
import contextlib,io,json,struct,unittest
from de25_customer_protocol import CustomerClient,ProtocolError,decode_snapshot,parse_reply,request
from de25_customer_console import PublicRecorder
from de25_customer_demo import run_customer_flow
from test_de25_customer_evidence import fixture as phase1_fixture


def tpm(body=b'',rc=0): return struct.pack('>HII',0x8001,10+len(body),rc)+body
def response(op,ident,body=b'',handle=0,flags=0x30,provider=0,state=8):
    return tpm(struct.pack('>BBBBIIHHIII',2,op,provider,state,ident,handle,1024,flags,0,0,len(body))+body)


class SoftwareBoardModel:
    def __init__(self):
        root=Path(__file__).resolve().parents[2]
        f=json.loads((root/'Testing/Simulation/Key Generation/reference/expected_keys.json').read_text(encoding='utf-8'))
        assert f['test_only']; self.fixture={k:int(v,0) for k,v in f['results'][0]['key'].items()}
        self.status_callback=None; self.expected_provider=0; self.sequence=0; self.state=0
        self.calls=[]; self.aes_key=bytes(range(32)); self.bad_caps=False
        self.bad_aes=False; self.bad_rsa=False; self.provider=0

    def poll_status(self,force=False):
        word=(1<<24)|0x80|(self.provider<<4)|self.state
        snap=dict(status_word=word,operation_id=len(self.calls),sequence=self.sequence,
                  state=self.state,detail=0,provider=self.provider)
        if self.status_callback: self.status_callback(snap)
        return snap

    def status(self,state):
        self.state=state; self.sequence+=1; self.poll_status(force=True)

    def transact(self,packet,timeout_s=185):
        self.calls.append(bytes(packet))
        if int.from_bytes(packet[6:10],'big')==0x144: self.status(0); return tpm()
        ver,op,flags,ident,handle,reserved=struct.unpack('>BBHIII',packet[10:26]); body=packet[26:]
        assert ver==2 and reserved==0
        if op==0:
            b=struct.pack('>HHHHIIII',256,1024 if self.bad_caps else 2048,1024,240,50000000,0xD40F80,0xD40FA0,7)
            return response(op,ident,b,provider=self.provider,state=0)
        if op==1:
            assert flags==1; self.status(3); self.status(5)
            return response(op,ident,self.aes_key,handle=0x80000001,flags=0x31,provider=self.provider,state=5)
        if op==2:
            assert handle==0x80000001 and flags==0
            self.status(6); iv=body[:16]; n=int.from_bytes(body[16:18],'big'); ct=body[18:]
            assert len(ct)==n
            from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
            d=Cipher(algorithms.AES(self.aes_key),modes.CFB(iv)).decryptor(); pt=d.update(ct)+d.finalize()
            if self.bad_aes: pt=b'X'*n
            take=n%16 or 16; final=(ct[-take:]+bytes(16-take)) if n else iv; self.status(8)
            return response(op,ident,len(pt).to_bytes(2,'big')+pt+final,handle=handle)
        if op==3:
            self.status(4); self.status(5)
            b=b'\1\0'+self.fixture['n'].to_bytes(256,'big')+b'\0\4'+self.fixture['e'].to_bytes(4,'big')
            return response(op,ident,b,handle=0x80000002,flags=0x31,state=5)
        if op==4:
            assert handle==0x80000002 and body[:2]==b'\1\0' and len(body)==258
            self.status(7)
            # ONLY THIS SOFTWARE MODEL uses a known TEST fixture private exponent.
            raw=pow(int.from_bytes(body[2:],'big'),self.fixture['d'],self.fixture['n']).to_bytes(256,'big')
            assert raw[:5]==b'\0DE25'; n=int.from_bytes(raw[5:7],'big'); assert n<=240 and not any(raw[7+n:])
            pt=raw[7:7+n]
            if self.bad_rsa: pt=b'wrong'
            self.status(8); return response(op,ident,len(pt).to_bytes(2,'big')+pt,handle=handle)
        raise AssertionError(f'Unexpected model operation {op}')


class ProtocolTests(unittest.TestCase):
    def test_explicit_export_flag_and_no_host_abi_fallback(self):
        with self.assertRaises(ValueError): request(1,1)
        with self.assertRaises(ValueError): request(0,1,allow_export=True)
        p=request(1,42,allow_export=True)
        self.assertEqual(p,bytes.fromhex('8001 0000001a 20000101 02 01 0001 0000002a 00000000 00000000'))

    def test_reply_identity_length_flags_and_provider_errors(self):
        valid=response(1,42,bytes(32),handle=1,flags=0x31)
        self.assertEqual(len(parse_reply(valid,1,42,0).body),32)
        bad=[(valid,1,43,0),(valid,1,42,1),(response(1,42,b'',flags=0x34),1,42,0),
             (valid+b'X',1,42,0),(tpm(b'secret',rc=0x101),1,42,0),
             (response(1,42,b'',flags=0x32),1,42,0)]
        for raw,op,ident,provider in bad:
            with self.assertRaises(ProtocolError): parse_reply(raw,op,ident,provider)

    def test_actual_live_snapshot_little_endian_coherence(self):
        word=(1<<24)|(37<<16)|0x80|4
        raw=struct.pack('<IIII',7,word,42,7)
        decoded=decode_snapshot(raw,0)
        self.assertEqual((decoded['state'],decoded['operation_id'],decoded['detail']),(4,42,37))
        self.assertIsNone(decode_snapshot(struct.pack('<IIII',7,word,42,8),0))
        self.assertIsNone(decode_snapshot(struct.pack('<IIII',7,0,42,7),0))
        with self.assertRaises(ProtocolError): decode_snapshot(raw,1)
        with self.assertRaises(ProtocolError): decode_snapshot(struct.pack('<IIII',7,word|0x40,42,7),0)

    def test_full_software_flow_location_order_and_no_key_record(self):
        model=SoftwareBoardModel(); rec=PublicRecorder()
        client=CustomerClient(model,0,rec)
        with contextlib.redirect_stdout(io.StringIO()):
            result=run_customer_flow(client,rec,phase1_fixture(),True,auto=True,message='Lenovo café',rsa_message='FPGA private RSA!')
        self.assertTrue(result['aes']['plaintext_match']); self.assertTrue(result['rsa']['plaintext_match'])
        self.assertEqual(result['rsa']['returned_plaintext'],'FPGA private RSA!')
        self.assertEqual([p[11] for p in model.calls if int.from_bytes(p[6:10],'big')==0x20000101],[0,1,2,3,4])
        self.assertEqual(rec.events[0]['event'],'phase1-start')
        self.assertEqual(len([e for e in rec.events if e['event']=='phase1-suite']),8)
        serialized=json.dumps(rec.events)
        self.assertNotIn(model.aes_key.hex(),serialized)
        self.assertNotIn(hex(model.fixture['d'])[2:],serialized)
        self.assertFalse(result['rsa']['private_context_exported'])
        self.assertFalse(result['lcd_glass_verified'])
        self.assertTrue(result['hardware_statuses'])

    def test_mismatched_caps_stops_before_any_generation(self):
        m=SoftwareBoardModel(); m.bad_caps=True
        with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(ProtocolError):
            run_customer_flow(CustomerClient(m,0),PublicRecorder(),phase1_fixture(),True,auto=True)
        self.assertEqual(len(m.calls),2)

    def test_wrong_actual_plaintext_never_claims_pass(self):
        for attr in ('bad_aes','bad_rsa'):
            m=SoftwareBoardModel(); setattr(m,attr,True); rec=PublicRecorder()
            with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(ProtocolError):
                run_customer_flow(CustomerClient(m,0),rec,phase1_fixture(),True,auto=True)
            self.assertNotIn('customer-flow-pass',[e['event'] for e in rec.events])

    def test_authorization_denied_before_command(self):
        m=SoftwareBoardModel()
        with self.assertRaises(ValueError): CustomerClient(m).generate_aes_export(False)
        self.assertEqual(m.calls,[])

    def test_phase1_gate_is_not_bypassed_by_library_entry(self):
        m=SoftwareBoardModel(); evidence=phase1_fixture(); evidence['suites'][2]['failures']=1
        with self.assertRaises(ValueError):
            run_customer_flow(CustomerClient(m),PublicRecorder(),evidence,True,auto=True)
        self.assertEqual(m.calls,[])


if __name__=='__main__': unittest.main()
