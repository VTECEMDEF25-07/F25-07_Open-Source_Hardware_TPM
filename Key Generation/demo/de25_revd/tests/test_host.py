# Filename: test_host.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Checks host behavior and reports failures.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Offline client checks. No DLL, USB, or board is opened."""
import hashlib
import importlib.util
import json
import itertools
import tempfile
from pathlib import Path
import sys
import unittest
from unittest.mock import patch, Mock
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE))
sys.path.insert(0,str(HERE.parents[1]/'reference'))
spec=importlib.util.spec_from_file_location('host_test',HERE/'host_test.py')
host=importlib.util.module_from_spec(spec);spec.loader.exec_module(host)
FIXTURE={'id':1,'seed_hex':'00'*31+'01'}

class DedicatedIdentityTests(unittest.TestCase):
    def test_rejects_cpu_image_before_any_operation(self):
        for configuration in (5, 7):
            adapter = FakeAdapter()
            adapter.reg[1] = configuration
            with self.assertRaisesRegex(RuntimeError, "CPU-controlled image"):
                host.identify(adapter)


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

class FaultAdapter(FakeAdapter):
    def __init__(self, wrong_status=False, stale=False, owned=False, stale_ack=False):
        super().__init__()
        self.wrong_status=wrong_status;self.stale=stale;self.owned=owned
        self.stale_ack=stale_ack
        self.resets=0
    def reset_board_core(self):
        self.resets+=1
        self.reg={0:0x4b473031,1:4,3:1,6:1000,7:0,13:0x002a0020,14:4000,15:0x0300}
        self.words=[];self.metas=[]
    def register(self,address,value=None):
        result=super().register(address,value)
        if address==2 and value==1:
            self.reg[3]=2
            self.reg[12]=4|(8 if self.reg[11]&2 else 0)|(16 if self.reg[11]&4 else 0)
        if address==11 and value is not None and value&8:
            self.reg[3]=(0x408 if self.wrong_status else 0x208)
            self.reg[12]=4|(32 if self.owned else 0)
            self.words=[1] if self.stale else [];self.metas=[]
        if address==2 and value==2 and self.stale_ack:
            self.reg[3]=0x201
        return result


class HostTests(unittest.TestCase):
    def test_source_fault_boundaries_and_reuse_without_reset(self):
        adapter=FaultAdapter();results=[]
        with patch.object(host,'run_key',return_value={'result':'PASS'}) as replay:
            host.fault_replay(adapter,FIXTURE,results)
        self.assertEqual(adapter.resets,1)
        self.assertEqual([r['fault_boundary'] for r in results[:4]],
                         ['generation_stall','rsa_active','result_stall','ownership_stall'])
        self.assertEqual([call.args[1] for call in replay.call_args_list],[0,1,2])
        self.assertTrue(all(r['observed_status']==2 and r['no_stale_result'] for r in results[:4]))
    def test_source_fault_rejects_wrong_status_stale_data_and_owned_result(self):
        for options,message in (({'wrong_status':True},'status 2'),
                                ({'stale':True},'stale result'),({'owned':True},'ownership'),
                                ({'stale_ack':True},'stale state')):
            adapter=FaultAdapter(**options)
            with patch.object(host,'run_key') as replay:
                with self.assertRaisesRegex(RuntimeError,message) as caught:
                    host.fault_replay(adapter,FIXTURE,[])
            replay.assert_not_called()
            self.assertEqual(adapter.resets,2)
            self.assertTrue(caught.exception.recovery['success'])
    def test_source_fault_failure_keeps_primary_if_recovery_fails(self):
        adapter=FaultAdapter(wrong_status=True)
        with patch.object(host,'recover_operation',side_effect=lambda a,e,force_reset:host.append_cleanup(e,'reset',OSError('recovery failed'))):
            with self.assertRaisesRegex(RuntimeError,'status 2') as caught:
                host.fault_replay(adapter,FIXTURE,[])
        self.assertEqual(caught.exception.cleanup_errors,['reset: recovery failed'])
    def test_diagnostics_only_for_declared_version(self):
        adapter=FakeAdapter()
        self.assertNotIn('fan_fault_reasons',host.telemetry(adapter))
        adapter.reg.update({32:0x102,33:0x20308000,34:0x55420102})
        adapter.fan_diagnostics_version=1
        sample=host.telemetry(adapter)
        self.assertEqual(sample['fan_fault_reasons'],['identity'])
        self.assertTrue(sample['conversion_wait'])
        self.assertEqual(sample['device'],0x42)
    def test_unknown_diagnostic_version_rejected(self):
        adapter=FakeAdapter();fingerprint='0123456789abcdef'*4
        for index in range(8):adapter.reg[24+index]=int(fingerprint[index*8:index*8+8],16)
        manifest={'variant':'rtl_generic','build_fingerprint':fingerprint,'fan_diagnostics_version':2}
        with self.assertRaisesRegex(RuntimeError,'diagnostic version'):host.identify(adapter,manifest)
        manifest['fan_diagnostics_version']=1
        host.identify(adapter,manifest)
        self.assertEqual(adapter.fan_diagnostics_version,1)
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
        def fail(a,mask,samples=None,source_schedule=None,transitions=None,**kwargs):
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
        with patch.object(host.time,'monotonic',side_effect=itertools.chain([0,0,181],itertools.repeat(181))),patch.object(host.time,'sleep'):
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
        with patch.object(host,'reset_and_check'),patch.object(host,'configure_request'),patch.object(host,'poll',return_value=2),patch.object(host.time,'monotonic',side_effect=itertools.chain([0,0,181],itertools.repeat(181))),patch.object(host.time,'sleep'):
            with self.assertRaisesRegex(TimeoutError,'enter RUN'):
                host.reset_replay(adapter,FIXTURE,results)
        self.assertEqual(results,[])

    def test_timeout_resets_stalled_operation(self):
        adapter=FakeAdapter()
        def stalled(a,mask,*args,**kwargs):
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
        def stalled(a,mask,*args,**kwargs):
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

    def test_start_write_failure_recovers_ambiguous_admission(self):
        adapter=FakeAdapter();register=adapter.register;primary=OSError('START response lost')
        def fail_start(address,value=None):
            result=register(address,value)
            if address==2 and value==1:
                adapter.reg[3]=2
                raise primary
            return result
        with patch.object(adapter,'register',side_effect=fail_start),patch.object(adapter,'reset_board_core',wraps=adapter.reset_board_core) as reset:
            with self.assertRaises(OSError) as caught:host.run_key(adapter,0,FIXTURE,1)
        self.assertIs(caught.exception,primary)
        reset.assert_called_once()
        self.assertEqual(primary.recovery,{'action':'reset','success':True})
        self.assertEqual(adapter.register(3),1)

    def test_stuck_run_boundary_resets_before_propagating(self):
        adapter=FakeAdapter();results=[]
        def pre_admission(*args):adapter.reg.update({3:2,12:2,11:1})
        with patch.object(host,'configure_request',side_effect=pre_admission),patch.object(host,'poll',side_effect=lambda a,mask,*args,**kwargs:mask),patch.object(host,'wait_running',side_effect=TimeoutError('demo did not enter RUN before reset boundary')),patch.object(host.time,'sleep'),patch.object(adapter,'reset_board_core',wraps=adapter.reset_board_core) as reset:
            with self.assertRaisesRegex(TimeoutError,'enter RUN') as caught:
                host.reset_replay(adapter,FIXTURE,results)
        self.assertEqual(reset.call_count,2)
        self.assertEqual(results,[])
        self.assertEqual(adapter.register(3),1)
        self.assertEqual(adapter.register(11),0)
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':True})

    def test_boundary_failure_survives_recovery_failure(self):
        primary=TimeoutError('boundary timeout');results=[]
        with patch.object(host,'reset_and_check',side_effect=[None,OSError('reset unavailable')]),patch.object(host,'configure_request'),patch.object(host,'poll',return_value=2),patch.object(host,'wait_running',side_effect=primary):
            with self.assertRaises(TimeoutError) as caught:host.reset_replay(FakeAdapter(),FIXTURE,results)
        self.assertIs(caught.exception,primary)
        self.assertEqual(primary.cleanup_errors,['reset: reset unavailable'])
        self.assertEqual(results,[])

    def test_late_ready_status_is_timeout(self):
        adapter=FakeAdapter();now=[0]
        def late(address,value=None):
            now[0]=181
            return 8
        with patch.object(adapter,'register',side_effect=late),patch.object(host.time,'monotonic',side_effect=lambda:now[0]):
            with self.assertRaises(TimeoutError):host.poll(adapter,8,deadline=180)

    def test_late_final_ack_cannot_turn_into_pass(self):
        adapter=FakeAdapter();register=adapter.register;now=[0]
        def late_ack(address,value=None):
            value_out=register(address,value)
            if address==2 and value==2:now[0]=181
            return value_out
        with patch.object(adapter,'register',side_effect=late_ack),patch.object(host.time,'monotonic',side_effect=lambda:now[0]):
            with self.assertRaises(TimeoutError) as caught:host.run_key(adapter,0,FIXTURE,1)
        self.assertEqual(caught.exception.recovery,{'action':'reset','success':True})

    def test_verification_deadline_still_fails_valid_key(self):
        adapter=FakeAdapter();now=[0]
        def late_check(key):now[0]=181
        with patch('key_checker.check_key',side_effect=late_check),patch.object(host.time,'monotonic',side_effect=lambda:now[0]):
            with self.assertRaises(TimeoutError):host.run_key(adapter,2,FIXTURE,1)

    def test_recovery_has_ten_second_budget_and_accumulates_errors(self):
        adapter=FakeAdapter();now=[0];primary=TimeoutError('original');primary.cleanup_errors=['earlier transport error']
        def slow_ack(address,value=None):now[0]=11;return 0
        with patch.object(adapter,'register',side_effect=slow_ack),patch.object(adapter,'reset_board_core') as reset,patch.object(host.time,'monotonic',side_effect=lambda:now[0]):
            host.recover_operation(adapter,primary,force_reset=False)
        reset.assert_not_called()
        self.assertEqual(primary.cleanup_errors[0],'earlier transport error')
        self.assertEqual(primary.recovery,{'action':'reset','success':False})
        self.assertEqual(primary.recovery_seconds,11)

    def test_transfer_preserves_read_error_when_cs_release_fails(self):
        adapter=object.__new__(host.SpiAdapter);primary=TimeoutError('USB read timeout')
        with patch.object(adapter,'pins',side_effect=[None,OSError('release failed')]),patch.object(adapter,'write'),patch.object(adapter,'read',side_effect=primary):
            with self.assertRaises(TimeoutError) as caught:adapter.transfer(b'x')
        self.assertIs(caught.exception,primary)
        self.assertEqual(primary.cleanup_errors,['chip-select release: release failed'])

    def test_initialization_preserves_error_when_close_fails(self):
        dll=Mock()
        def count(pointer):pointer._obj.value=1;return 0
        def detail(index,flags,kind,identifier,location,serial,description,handle):
            kind._obj.value=8;serial.value=host.SERIAL.encode();description.value=b'C232HM';return 0
        def opened(serial,mode,handle):handle._obj.value=123;return 0
        dll.FT_CreateDeviceInfoList.side_effect=count;dll.FT_GetDeviceInfoDetail.side_effect=detail;dll.FT_OpenEx.side_effect=opened
        dll.FT_ResetDevice.return_value=7
        with patch.object(host.c,'WinDLL',return_value=dll),patch.object(host.SpiAdapter,'close',side_effect=OSError('initialization close failed')):
            with self.assertRaisesRegex(RuntimeError,'reset adapter') as caught:host.SpiAdapter()
        self.assertEqual(caught.exception.cleanup_errors,['adapter initialization close: initialization close failed'])

    def test_provenance_rejects_changed_reference(self):
        scratch=next((p/'AI/tmp' for p in HERE.parents if (p/'AI/tmp').is_dir()),
                     HERE.parents[1]/'build/test_host_tmp').resolve()
        scratch.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as directory:
            root=Path(directory).resolve();root.relative_to(scratch)
            for name in ('host_test.py','fan_diagnostics.py','key_checker.py','keygen_reference.py','seeds.json','expected_keys.json'):
                (root/name).write_text('original')
            with patch.object(host,'__file__',str(root/'host_test.py')):
                fingerprints=host.provenance_inputs(root)
                self.assertEqual(len(fingerprints),6)
                host.verify_provenance(root,fingerprints)
                (root/'expected_keys.json').write_text('changed')
                with self.assertRaisesRegex(RuntimeError,'inputs changed'):host.verify_provenance(root,fingerprints)

    def test_driver_close_failure_is_reported_without_masking_write_error(self):
        for fail_write in (False,True):
            adapter=object.__new__(host.SpiAdapter);adapter.handle=host.c.c_void_p(123);adapter.dll=Mock();adapter.dll.FT_Close.return_value=7
            primary=OSError('tri-state write failed')
            with patch.object(adapter,'write',side_effect=primary if fail_write else None):
                if fail_write:
                    with self.assertRaises(OSError) as caught:adapter.close()
                    self.assertIs(caught.exception,primary)
                    self.assertEqual(primary.cleanup_errors,['driver close: close adapter: FT_STATUS=7'])
                else:
                    with self.assertRaisesRegex(RuntimeError,'close adapter'):adapter.close()
            self.assertFalse(adapter.handle.value)

if __name__=='__main__':unittest.main()
