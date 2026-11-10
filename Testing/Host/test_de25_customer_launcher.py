"""Software-only launcher gates. Injected processes never open hardware/FTDI."""
from argparse import Namespace
from datetime import timedelta
from pathlib import Path
import contextlib,hashlib,io,json,os,subprocess,sys,tempfile,unittest
from unittest.mock import patch
import de25_customer_demo_launcher as launcher
from test_de25_customer_evidence import fixture


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.work=Path(__file__).resolve().parents[3]/'launcher-test-tmp';self.work.mkdir(exist_ok=True)
        self.temp=tempfile.TemporaryDirectory(dir=self.work);self.base=Path(self.temp.name)
        assert self.base.resolve().is_relative_to(self.work.resolve())
        self.runner=self.base/'runner with spaces'/'run_phase1.py';self.runner.parent.mkdir()
        self.runner.write_text('# SOFTWARE TEST STUB; never executed\n')
        exe=self.runner.with_name('phase1_tester.exe');exe.write_bytes(b'SOFTWARE TEST STUB; not executable')
        self.exe_sha=hashlib.sha256(exe.read_bytes()).hexdigest()
        self.args=Namespace(allow_demo_key_export=True,source_commit='b'*40,image_sha256='a'*64,
                            phase1_runner=self.runner,phase1_runner_sha256=None,
                            record_dir=self.base/'new capture',spi_hz=1000000,
                            transport='de25_customer_transport:factory',auto=False,
                            message='$(literal text); not a command',rsa_message=None,status_relay=None)
        self.calls=[];self.mutate=lambda record:None;self.mutate_log=lambda text:text
        self.pins=patch.object(launcher,'EXPECTED_PHASE1_EXE_SHA256',self.exe_sha);self.pins.start()

    def tearDown(self):
        self.pins.stop()
        assert self.base.resolve().is_relative_to(self.work.resolve())
        self.temp.cleanup()

    def phase_process(self,argv):
        self.calls.append(('phase1',argv))
        self.assertIsInstance(argv,list);self.assertEqual(argv[2],str(self.runner.resolve()))
        label=argv[argv.index('--label')+1];out=self.runner.parent/label;out.mkdir()
        record=fixture();record.update(spi_hz=1000000,return_code=0,hardware_lock_released=True,
            exe_sha256=self.exe_sha,started_utc=launcher.now().isoformat(),ended_utc=launcher.now().isoformat(),
            log_path=str((out/'hardware.log').resolve()),source_audit={
                'all_eight_suite_bodies_byte_identical':True,'assertion_predicates_unchanged':True,
                'original_sha256':launcher.EXPECTED_ORIGINAL_C_SHA256})
        self.mutate(record)
        text='\n'.join(f"PHASE1_SUITE_END {s['name']} assertions={s['assertion_calls']} failures=0" for s in record['suites'])
        text+='\nPHASE1_TOTAL assertions=28 failures=0 completed=8\nThere were no errors in testing.\n'
        (out/'hardware.log').write_text(self.mutate_log(text));(out/'result.json').write_text(json.dumps(record))
        return subprocess.CompletedProcess(argv,0,'SOFTWARE MODEL of native runner output\n')

    def customer_process(self,argv,environment):
        self.calls.append(('customer',argv))
        self.assertEqual(environment['DE25_SPI_HZ'],'1000000')
        self.assertEqual(environment['PYTHONUTF8'],'1')
        self.assertEqual(environment['PYTHONIOENCODING'],'utf-8')
        self.assertTrue((self.args.record_dir/'phase1/result.json').is_file())
        self.assertEqual(argv[argv.index('--message')+1],self.args.message)
        (self.args.record_dir/'summary.json').write_text(json.dumps(dict(status='PASS',source_commit='b'*40,sof_sha256='a'*64)))
        return 0

    def execute(self,phase=None,customer=None):
        with contextlib.redirect_stdout(io.StringIO()):
            return launcher.execute_session(self.args,phase or self.phase_process,customer or self.customer_process)

    def test_new_execution_precedes_crypto_and_archives_original_output(self):
        result=self.execute()
        self.assertEqual([x[0] for x in self.calls],['phase1','customer'])
        self.assertEqual(result['status'],'PASS');self.assertEqual(result['phase1_suite_count'],8)
        self.assertEqual(result['phase1_assertion_count'],28)
        self.assertIn('PHASE1_SUITE_END', (self.args.record_dir/'phase1/hardware.log').read_text())
        self.assertIn('SOFTWARE MODEL',(self.args.record_dir/'phase1-runner.stdout.txt').read_text())

    def test_phase1_nonzero_never_opens_crypto(self):
        with self.assertRaises(launcher.SessionError):
            self.execute(phase=lambda argv:subprocess.CompletedProcess(argv,1,'failed'))
        self.assertFalse(self.calls)
        self.assertEqual(json.loads((self.args.record_dir/'launcher.result.json').read_text())['status'],'FAIL')

    def test_stale_result_never_opens_crypto(self):
        self.mutate=lambda r:r.update(started_utc=(launcher.now()-timedelta(hours=1)).isoformat())
        with self.assertRaises(launcher.SessionError):self.execute()
        self.assertEqual([x[0] for x in self.calls],['phase1'])

    def test_wrong_source_image_or_unreleased_mutex_never_opens_crypto(self):
        for key,value in [('source_commit','c'*40),('sof_sha256','d'*64),('hardware',False),('hardware_lock_released',False)]:
            with self.subTest(key=key):
                self.args.record_dir=self.base/key;self.calls=[]
                self.mutate=lambda r,k=key,v=value:r.update({k:v})
                with self.assertRaises((ValueError,launcher.SessionError)):self.execute()
                self.assertEqual([x[0] for x in self.calls],['phase1'])

    def test_fresh_log_requires_all_eight_original_completions(self):
        self.mutate_log=lambda text:text.replace('PHASE1_SUITE_END test_ccQuote','REMOVED test_ccQuote')
        with self.assertRaises(launcher.SessionError):self.execute()
        self.assertEqual([x[0] for x in self.calls],['phase1'])

    def test_changed_executable_or_assertions_denied(self):
        self.runner.with_name('phase1_tester.exe').write_bytes(b'changed')
        with self.assertRaises(launcher.SessionError):self.execute()
        self.assertFalse(self.calls)

    def test_changed_original_assertion_audit_never_opens_crypto(self):
        self.mutate=lambda r:r['source_audit'].update(assertion_predicates_unchanged=False)
        with self.assertRaises(launcher.SessionError):self.execute()
        self.assertEqual([x[0] for x in self.calls],['phase1'])

    def test_existing_record_directory_is_never_reused(self):
        self.args.record_dir.mkdir()
        with self.assertRaises(FileExistsError):self.execute()
        self.assertFalse(self.calls)

    def test_crypto_error_never_creates_successful_session(self):
        with self.assertRaises(launcher.SessionError):self.execute(customer=lambda argv,env:1)
        self.assertEqual(json.loads((self.args.record_dir/'launcher.result.json').read_text())['status'],'FAIL')

    def test_phase1_child_output_is_utf8_with_legacy_parent_encoding(self):
        # A tiny Python child only; never the hardware runner or a driver.
        with patch.dict(os.environ,{'PYTHONUTF8':'0','PYTHONIOENCODING':'cp1252'}):
            result=launcher.run_phase1([sys.executable,'-c',"print('OFFLINE λ 🌐')"])
        self.assertEqual(result.returncode,0,result.stdout)
        self.assertEqual(result.stdout.strip(),'OFFLINE λ 🌐')


if __name__=='__main__':unittest.main()
