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
    def reset_board_core(self):
        self.__init__()
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
        if address==9:return self.words[self.reg[8]] if self.words else 0
        if address==10:return self.metas[self.reg[8]] if self.metas else 0
        return self.reg.get(address,0)

class HostTests(unittest.TestCase):
    def test_build_fingerprint(self):
        adapter=FakeAdapter();fingerprint='0123456789abcdef'*4
        for index in range(8):adapter.reg[24+index]=int(fingerprint[index*8:index*8+8],16)
        manifest={'variant':'rtl_generic','build_fingerprint':fingerprint}
        self.assertEqual(host.identify(adapter,manifest)['build_fingerprint'],fingerprint)
        adapter.reg[31]^=1
        with self.assertRaisesRegex(RuntimeError,'fingerprint'):host.identify(adapter,manifest)
    def test_stall_replay_checks_both_completions(self):
        results=[]
        with patch.object(host,'run_key',return_value={'result':'PASS'}) as run:
            host.stall_replay(FakeAdapter(),FIXTURE,results)
        self.assertEqual(len(results),2)
        self.assertEqual([c.args[1:3] for c in run.call_args_list],[(2,FIXTURE),(2,FIXTURE)])
        self.assertIsNone(run.call_args_list[0].kwargs['source_schedule'])
        self.assertEqual(run.call_args_list[1].kwargs['source_schedule'][-1],(.30,0))
    def test_stall_failure_releases_source(self):
        adapter=FakeAdapter()
        def fail(a,mask,samples=None,source_schedule=None,transitions=None):
            if mask==1:return 1
            a.register(11,1)
            raise TimeoutError('injected timeout')
        with patch.object(host,'poll',side_effect=fail):
            with self.assertRaises(TimeoutError):host.run_key(adapter,2,FIXTURE,1,source_schedule=[(0,1)])
        self.assertEqual(adapter.register(11),0)
    def test_stall_schedule_releases_before_completion(self):
        adapter=FakeAdapter();adapter.reg[3]=2;transitions=[]
        counter=[0]
        def now():
            counter[0]+=.01
            if counter[0]>.3:adapter.reg[3]=12
            return counter[0]
        with patch.object(host.time,'monotonic',side_effect=now),patch.object(host.time,'sleep'):
            host.poll(adapter,8,source_schedule=[(.02,1),(.10,0)],transitions=transitions)
        self.assertEqual([x['hold_generation'] for x in transitions],[True,False])
        self.assertEqual(adapter.register(11),0)
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

    def test_soak_mixes_profiles_and_checkpoints(self):
        results=[];checkpoints=[]
        times=[0,0,10,10,20,20,30,30,30]
        with patch.object(host.time,'monotonic',side_effect=times),patch.object(host,'run_key',return_value={'result':'PASS'}) as run:
            summary=host.soak(FakeAdapter(),[FIXTURE],results,lambda:checkpoints.append(1),duration=25)
        self.assertEqual([call.args[1] for call in run.call_args_list],[0,1,2])
        self.assertEqual(summary['soak_jobs'],3);self.assertEqual(len(checkpoints),3)
    def test_soak_failure_does_not_claim_pass(self):
        with patch.object(host.time,'monotonic',side_effect=[0,0]),patch.object(host,'run_key',side_effect=RuntimeError('bad result')):
            with self.assertRaisesRegex(RuntimeError,'bad result'):host.soak(FakeAdapter(),[FIXTURE],[],duration=25)
    def test_reset_suite_boundaries_and_replay(self):
        adapter=FakeAdapter();results=[]
        def configure(adapter,profile,fixture,request_id,controls):
            adapter.reg[3]=4 if controls==4 else 12 if profile==0 and controls==0 else 2
            adapter.reg[12]=12
        with patch.object(host,'configure_request',side_effect=configure),patch.object(host.time,'sleep'),patch.object(host,'run_key',side_effect=lambda a,p,f,r:{'profile':p,'result':'PASS'}):
            host.reset_replay(adapter,FIXTURE,results)
        self.assertEqual(len(results),8)
        self.assertEqual([x['profile'] for x in results if 'profile' in x],[0,1,2])
    def test_reset_stale_data_rejected(self):
        adapter=FakeAdapter()
        with patch.object(adapter,'reset_board_core',side_effect=lambda:adapter.reg.update({3:13})):
            with self.assertRaisesRegex(RuntimeError,'stale status'):host.reset_and_check(adapter)

    def test_reset_boundary_rejects_busy_before_admission(self):
        adapter=FakeAdapter();adapter.reg.update({3:2,12:2});results=[]
        with patch.object(host,'reset_and_check'),patch.object(host,'configure_request'),patch.object(host,'poll',return_value=2),patch.object(host.time,'monotonic',side_effect=[0,0,181]),patch.object(host.time,'sleep'):
            with self.assertRaisesRegex(TimeoutError,'enter RUN'):
                host.reset_replay(adapter,FIXTURE,results)
        self.assertEqual(results,[])

    def test_timeout_resets_stalled_operation(self):
        adapter=FakeAdapter()
        def stalled(a,mask,*args):
            if mask==8:raise TimeoutError('primary generation timeout')
            return 1
        with patch.object(host,'poll',side_effect=stalled),patch.object(adapter,'reset_board_core',wraps=adapter.reset_board_core) as reset:
            with self.assertRaisesRegex(TimeoutError,'primary generation timeout') as caught:
                host.run_key(adapter,0,FIXTURE,1)
        reset.assert_called_once()
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':True})
        self.assertEqual(adapter.reg[3],1)

    def test_primary_key_failure_survives_ack_failure(self):
        adapter=FakeAdapter();adapter.corrupt_data=True;register=adapter.register
        def fail_ack(address,value=None):
            if address==2 and value==2:raise OSError('cleanup ACK failed')
            return register(address,value)
        with patch.object(adapter,'register',side_effect=fail_ack),patch.object(adapter,'reset_board_core',wraps=adapter.reset_board_core) as reset:
            with self.assertRaisesRegex(RuntimeError,'AES fixture mismatch') as caught:
                host.run_key(adapter,0,FIXTURE,1)
        reset.assert_called_once()
        self.assertEqual(caught.exception.cleanup_errors,['acknowledge: cleanup ACK failed'])
        self.assertTrue(caught.exception.fan_samples)
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':True})

    def test_successful_key_with_failed_ack_still_fails(self):
        adapter=FakeAdapter();register=adapter.register
        def fail_ack(address,value=None):
            if address==2 and value==2:raise OSError('completion ACK failed')
            return register(address,value)
        with patch.object(adapter,'register',side_effect=fail_ack):
            with self.assertRaisesRegex(OSError,'completion ACK failed') as caught:
                host.run_key(adapter,0,FIXTURE,1)
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':True})

    def test_timeout_survives_reset_failure(self):
        adapter=FakeAdapter()
        def stalled(a,mask,*args):
            if mask==8:raise TimeoutError('primary timeout')
            return 1
        with patch.object(host,'poll',side_effect=stalled),patch.object(adapter,'reset_board_core',side_effect=OSError('reset unavailable')):
            with self.assertRaisesRegex(TimeoutError,'primary timeout') as caught:
                host.run_key(adapter,0,FIXTURE,1)
        self.assertEqual(caught.exception.cleanup_errors,['reset: reset unavailable'])
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':False})

    def test_adapter_close_does_not_mask_primary_failure(self):
        adapter=object.__new__(host.SpiAdapter);primary=TimeoutError('original failure')
        with patch.object(adapter,'close',side_effect=OSError('close failed')):
            adapter.__exit__(TimeoutError,primary,None)
        self.assertEqual(str(primary),'original failure')
        self.assertEqual(primary.cleanup_errors,['adapter close: close failed'])

if __name__=='__main__':unittest.main()
