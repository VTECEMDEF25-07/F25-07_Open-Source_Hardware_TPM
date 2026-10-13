"""Offline client checks. No DLL, USB, or board is opened."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[1]/'reference'))
spec=importlib.util.spec_from_file_location('host_test',HERE/'host_test.py')
host=importlib.util.module_from_spec(spec);spec.loader.exec_module(host)
FIXTURE={'id':1,'seed_hex':'00'*31+'01'}

class FakeAdapter:
    def __init__(self):
        self.reg={0:0x4b473031,1:4,3:1,6:1000,7:0,13:0x002a0020,14:4000,15:0x0300}
        self.words=[];self.metas=[];self.corrupt_data=False;self.corrupt_meta=False;self.error=False
        self.acked=False
    def transfer(self,data):
        assert len(data)==7
        return bytes(7)
    def register(self,address,value=None):
        if value is not None:
            self.reg[address]=value
            if address==2 and value==1:
                profile=self.reg[4]
                if profile<2:
                    seed=b''.join(self.reg[16+i].to_bytes(4,'big') for i in range(8))
                    digest=hashlib.sha256(b'KEYGEN-TEST-v1\0'+seed+bytes(8)).digest()
                    count=4 if profile==0 else 8
                    self.words=[int.from_bytes(digest[i*4:i*4+4],'big') for i in range(count)]
                    self.metas=[0x80000001|(i<<3)| (0xc00 if i==count-1 else 0) for i in range(count)]
                else:
                    key=json.loads((HERE.parents[1]/'reference/expected_keys.json').read_text())['results'][0]['key']
                    self.words=[];self.metas=[]
                    for component,name,count in ((2,'n',64),(3,'e',1),(4,'p',32),(5,'q',32)):
                        data=int(key[name],16).to_bytes(count*4,'big')
                        for i in range(count):
                            self.words.append(int.from_bytes(data[i*4:i*4+4],'big'))
                            self.metas.append(0x80000000|component|(i<<3)|(0x400 if i==count-1 else 0)|(0x800 if component==5 and i==31 else 0))
                if self.corrupt_data:self.words[0]^=1
                if self.corrupt_meta:self.metas[0]^=8
                self.reg[3]=0x208 if self.error else 12
            if address==2 and value==2:self.reg[3]=1;self.acked=True
            return 0
        if address==9:return self.words[self.reg[8]]
        if address==10:return self.metas[self.reg[8]]
        return self.reg.get(address,0)

class HostTests(unittest.TestCase):
    def test_transport(self):
        adapter=FakeAdapter();self.assertTrue(host.identify(adapter)['test_mode'])
        self.assertEqual(host.transport_test(adapter)['transport'],'PASS')
    def test_aes_both(self):
        for profile in (0,1):
            adapter=FakeAdapter();result=host.run_key(adapter,profile,FIXTURE,99)
            self.assertEqual(result['result'],'PASS');self.assertTrue(adapter.acked)
            self.assertEqual(result['fan_samples'][0]['fan_rpm'],4000)
    def test_rsa_corpus_and_independent_checker(self):
        adapter=FakeAdapter();self.assertEqual(host.run_key(adapter,2,FIXTURE,99)['result'],'PASS')
    def test_corrupt_aes_rejected_and_acked(self):
        adapter=FakeAdapter();adapter.corrupt_data=True
        with self.assertRaisesRegex(RuntimeError,'AES fixture'):host.run_key(adapter,1,FIXTURE,1)
        self.assertTrue(adapter.acked)
    def test_corrupt_metadata_rejected(self):
        adapter=FakeAdapter();adapter.corrupt_meta=True
        with self.assertRaisesRegex(RuntimeError,'component/index'):host.run_key(adapter,1,FIXTURE,1)
        self.assertTrue(adapter.acked)
    def test_error_status(self):
        adapter=FakeAdapter();adapter.error=True
        with self.assertRaisesRegex(RuntimeError,'status 2'):host.run_key(adapter,0,FIXTURE,1)
        self.assertTrue(adapter.acked)
    def test_timeout(self):
        with patch.object(host.time,'monotonic',side_effect=[0,0,181]),patch.object(host.time,'sleep'):
            with self.assertRaises(TimeoutError):host.poll(FakeAdapter(),8)
    def test_wrong_image(self):
        adapter=FakeAdapter();adapter.reg[1]=0
        with self.assertRaisesRegex(RuntimeError,'test-image'):host.identify(adapter)

if __name__=='__main__':unittest.main()
