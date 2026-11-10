#!/usr/bin/env python3
"""Run the original Phase I hardware suites, then the interactive customer flow.

Hardware lead supplies the already-programmed image identity and verified native
runner. This launcher never programs an FPGA or changes original test bodies.
"""
from datetime import datetime,timedelta,timezone
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,uuid
from de25_customer_evidence import load_phase1

EXPECTED_PHASE1_EXE_SHA256='dede832c08ccf5e7f7a2093139267ab5850b418b4da781b62f37913e9ffef9b3'
EXPECTED_ORIGINAL_C_SHA256='b4cf7a367b5275bffe646c71417e1dfd1cceb330950e43ead1131d0605ee8abe'

class SessionError(RuntimeError):pass


def now():return datetime.now(timezone.utc)


def stamp(value):
    result=datetime.fromisoformat(value)
    if result.tzinfo is None:raise SessionError('Phase I timestamp has no timezone')
    return result.astimezone(timezone.utc)


def validate_new_execution(path,source,image,started,ended,hz):
    record=load_phase1(path,image)
    if (record.get('hardware') is not True or record['source_commit']!=source or
            record.get('return_code')!=0 or record.get('hardware_lock_released') is not True or
            record['spi_hz']!=hz):
        raise SessionError('Phase I execution/source/hardware/transport/lock gate failed')
    audit=record.get('source_audit',{})
    if audit.get('all_eight_suite_bodies_byte_identical') is not True or audit.get('assertion_predicates_unchanged') is not True:
        raise SessionError('Original Phase I bodies/assertions must remain unchanged')
    if record.get('exe_sha256')!=EXPECTED_PHASE1_EXE_SHA256 or audit.get('original_sha256')!=EXPECTED_ORIGINAL_C_SHA256:
        raise SessionError('Phase I executable/original source differs from the frozen runner ABI')
    begin,finish=stamp(record['started_utc']),stamp(record['ended_utc'])
    if begin<started-timedelta(seconds=1) or finish<begin or finish>ended+timedelta(seconds=1):
        raise SessionError('Phase I result is not from this new execution')
    log=path.parent/'hardware.log'
    if Path(record['log_path']).resolve()!=log.resolve():
        raise SessionError('Phase I log does not belong to this new output directory')
    text=log.read_text(encoding='utf-8',errors='replace')
    actual=re.findall(r'PHASE1_SUITE_END (\w+) assertions=(\d+) failures=(\d+)',text)
    expected={(s['name'],str(s['assertion_calls']),'0') for s in record['suites']}
    totals=re.findall(r'PHASE1_TOTAL assertions=(\d+) failures=(\d+) completed=8',text)
    if (len(actual)!=8 or set(actual)!=expected or
            totals!=[(str(record['assertion_count']),'0')] or
            'There were no errors in testing.' not in text):
        raise SessionError('Fresh original hardware log does not match all eight result rows')
    return record


def utf8_environment():
    environment=os.environ.copy()
    environment.update(PYTHONUTF8='1',PYTHONIOENCODING='utf-8')
    return environment


def run_phase1(argv):
    # The verified runner bounds its native tester to 120 seconds and releases
    # the existing named hardware mutex in finally. No shell is involved.
    return subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                          text=True,encoding='utf-8',errors='replace',shell=False,env=utf8_environment())


def run_customer(argv,environment):
    # Inherit stdin/stdout so input() prompts remain visible during typing.
    return subprocess.call(argv,shell=False,env=environment)


def execute_session(args,phase1_process=run_phase1,customer_process=run_customer):
    if not args.allow_demo_key_export:raise SessionError('Explicit DEMO-only AES export acknowledgment is required')
    if not re.fullmatch('[0-9a-f]{40}',args.source_commit) or not re.fullmatch('[0-9a-f]{64}',args.image_sha256):
        raise SessionError('Supply exact lowercase source commit and SOF SHA256')
    runner=args.phase1_runner.resolve();root=args.record_dir.resolve()
    if not runner.is_file():raise SessionError('Verified native Phase I runner is missing')
    executable=runner.with_name('phase1_tester.exe')
    if not executable.is_file() or hashlib.sha256(executable.read_bytes()).hexdigest()!=EXPECTED_PHASE1_EXE_SHA256:
        raise SessionError('Native counted tester differs from the frozen executable')
    if args.phase1_runner_sha256 and hashlib.sha256(runner.read_bytes()).hexdigest()!=args.phase1_runner_sha256:
        raise SessionError('Native Phase I runner hash differs from the pinned runner')
    # A fresh record root and runner-owned unique label prohibit saved-result reuse.
    root.mkdir(parents=True,exist_ok=False)
    label='customer-'+now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8]
    phase_dir=runner.parent/label
    if phase_dir.exists():raise SessionError('Phase I output label already exists')
    argv=[sys.executable,'-u',str(runner),'--label',label,'--source',args.source_commit,
          '--sof-sha256',args.image_sha256,'--hz',str(args.spi_hz)]
    started=now()
    report=dict(status='RUNNING',started_utc=started.isoformat(),source_commit=args.source_commit,
                sof_sha256=args.image_sha256,phase1_argv=argv,phase1_output=str(phase_dir),
                phase1_runner_sha256=hashlib.sha256(runner.read_bytes()).hexdigest(),
                scope='Original Phase I executes first; crypto is admitted only after a new unchanged eight-suite PASS')
    def save():
        (root/'launcher.result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    save()
    try:
        print('PHASE I: running all eight original hardware suites now; waiting for actual completion.',flush=True)
        result=phase1_process(argv)
        output=result.stdout or ''
        (root/'phase1-runner.stdout.txt').write_text(output,encoding='utf-8')
        print(output,end='' if output.endswith('\n') else '\n',flush=True)
        report['phase1_return_code']=result.returncode
        if result.returncode!=0:raise SessionError('Original Phase I execution failed; customer crypto was not started')
        phase_result=phase_dir/'result.json'
        record=validate_new_execution(phase_result,args.source_commit,args.image_sha256,started,now(),args.spi_hz)
        archive=root/'phase1';archive.mkdir()
        for name in ['result.json','hardware.log']:
            shutil.copyfile(phase_dir/name,archive/name)
        report['phase1_completed_utc']=now().isoformat()
        report['phase1_suite_count']=record['suite_count'];report['phase1_assertion_count']=record['assertion_count']
        report['phase1_files_sha256']={name:hashlib.sha256((archive/name).read_bytes()).hexdigest()
                                      for name in ['result.json','hardware.log']}
        command=[sys.executable,'-u',str(Path(__file__).with_name('de25_customer_demo.py')),
                 '--allow-demo-key-export','--phase1-evidence',str(archive/'result.json'),
                 '--image-sha256',args.image_sha256,'--record-dir',str(root),'--transport',args.transport]
        if args.auto:command.append('--auto')
        for option,value in [('--message',args.message),('--rsa-message',args.rsa_message),('--status-relay',args.status_relay)]:
            if value is not None:command.extend([option,value])
        environment=utf8_environment();environment['DE25_SPI_HZ']=str(args.spi_hz)
        report['customer_argv']=command;report['customer_spi_hz']=args.spi_hz;save()
        print('PHASE I: new 8/8 PASS verified. Starting the customer AES/RSA flow.',flush=True)
        code=customer_process(command,environment);report['customer_return_code']=code
        if code!=0:raise SessionError('Customer AES/RSA process failed')
        summary=json.loads((root/'summary.json').read_text(encoding='utf-8'))
        if summary.get('status')!='PASS' or summary.get('source_commit')!=args.source_commit or summary.get('sof_sha256')!=args.image_sha256:
            raise SessionError('Customer process did not produce a matching successful summary')
        report['status']='PASS';report['ended_utc']=now().isoformat();save()
        return report
    except BaseException as exc:
        report['status']='FAIL';report['ended_utc']=now().isoformat();report['error']=f'{type(exc).__name__}: {exc}'
        save();raise


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--phase1-runner',type=Path,required=True)
    p.add_argument('--phase1-runner-sha256',help='Optional pin supplied by hardware lead')
    p.add_argument('--source-commit',required=True)
    p.add_argument('--image-sha256',required=True)
    p.add_argument('--record-dir',type=Path,required=True,help='New directory; existing directories are rejected')
    p.add_argument('--spi-hz',type=int,choices=(100000,1000000),default=1000000)
    p.add_argument('--allow-demo-key-export',action='store_true')
    p.add_argument('--transport',default='de25_customer_transport:factory')
    p.add_argument('--status-relay')
    p.add_argument('--auto',action='store_true')
    p.add_argument('--message');p.add_argument('--rsa-message')
    args=p.parse_args()
    if not args.allow_demo_key_export:p.error('--allow-demo-key-export is mandatory for this DEMO-only flow')
    execute_session(args)


if __name__=='__main__':main()
