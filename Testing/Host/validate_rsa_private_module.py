"""READ-ONLY independent audit of lead-generated RSA hardware validation records.

Never opens/programs hardware, generates keys, imports a private key, or performs
a private operation. Reuses the keygen owner's actual hardware sample window.
Only a complete same-image hardware record can produce a hardware metric.
"""
import argparse
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import statistics

SUITES={'test_debugRW','test_localityChanging','test_localityPermissions',
        'test_statusStateMachine','test_localitySeizeCommandAbort',
        'test_hierarchyControl','test_hierarchyControl2','test_ccQuote'}
FORBIDDEN={'d','p','q','private_exponent','prime_p','prime_q','private_key'}


def require(condition,message):
    if not condition:raise ValueError(message)


def no_private_material(value):
    if isinstance(value,dict):
        require(not ({str(key).lower() for key in value}&FORBIDDEN),'Private key material is not permitted in this audit record')
        for child in value.values():no_private_material(child)
    elif isinstance(value,list):
        for child in value:no_private_material(child)


def hex_bytes(value,label,size=None):
    require(isinstance(value,str) and len(value)%2==0 and re.fullmatch('[0-9a-fA-F]*',value) is not None,
            f'Invalid {label} hex')
    data=bytes.fromhex(value)
    require(size is None or len(data)==size,f'Invalid {label} byte length')
    return data


def elapsed(value,label):
    require(type(value) in (float,int) and math.isfinite(value) and value>0,f'Invalid {label}')
    return float(value)


def audit(record,phase1):
    no_private_material(record)
    require(record.get('status')=='PASS' and record.get('evidence_kind')=='HARDWARE',
            'Complete actual hardware keygen evidence is required; no simulation/pending fallback')
    require(phase1.get('status')=='PASS' and phase1.get('hardware',True) is True and
            phase1.get('simulation',False) is False and phase1.get('assertions_unchanged') is True,
            'Original unchanged Phase I hardware pass is required')
    source=record.get('source_revision','');sof=record.get('sof_sha256','')
    require(re.fullmatch('[0-9a-f]{40}',source) is not None and re.fullmatch('[0-9a-f]{64}',sof) is not None,
            'Exact source and SOF fingerprints are required')
    require(source==phase1.get('source_commit') and sof==phase1.get('sof_sha256'),
            'Phase I and RSA records are from different source/image')
    require(record.get('core_hz')==50000000==phase1.get('core_hz') and
            record.get('spi_hz')==phase1.get('spi_hz') and record.get('spi_hz') in (100000,1000000),
            'Expected the accepted 50MHz core and exact SPI rate')
    suites=phase1.get('suites',[])
    require(len(suites)==8 and {s.get('name') for s in suites}==SUITES and
            phase1.get('suite_count')==8 and type(phase1.get('failure_count')) is int and phase1['failure_count']==0 and
            phase1.get('completion_marker') is True,'All eight original Phase I suites must complete')
    for suite in suites:
        require(suite.get('completed') is True and type(suite.get('assertion_calls')) is int and
                suite['assertion_calls']>=0 and type(suite.get('failures')) is int and suite['failures']==0,
                'Phase I assertion/completion evidence is invalid')
        require(('status' not in suite or suite['status']=='PASS') and
                ('errors' not in suite or suite['errors']==suite['failures']) and
                ('assertions' not in suite or suite['assertions']==suite['assertion_calls']),
                'Conflicting Phase I suite aliases')
    require(type(phase1.get('assertion_count')) is int and
            phase1['assertion_count']>0 and phase1['assertion_count']==sum(s['assertion_calls'] for s in suites),
            'Phase I assertion count mismatch')
    require(all(phase1.get(key) for key in ('log_path','started_utc','ended_utc')),
            'Phase I raw log and timestamps must be retained')
    require(record.get('provider')=='FRESH_UNQUALIFIED' and record.get('entropy_qualified') is False and
            record.get('private_context_exported') is False and record.get('width_or_profile')=='RSA2048/e65537',
            'Requires explicitly unqualified fresh provider and internal RSA2048 private context')
    for name in ('started_utc','ended_utc'):
        value=datetime.fromisoformat(record.get(name,''))
        require(value.tzinfo is not None,'Validation timestamps must be timezone-aware')
    require(datetime.fromisoformat(record['ended_utc'])>=datetime.fromisoformat(record['started_utc']),
            'Validation end precedes start')
    keys=record.get('keys',[]);per_key=record.get('messages_per_key')
    require(keys and type(per_key) is int and per_key>0,'Missing private sample set')
    require(record.get('generated_keys')==len(keys)==record.get('distinct_moduli')==record.get('samples_requested'),
            'Key sample denominators disagree')
    seen_n=set();seen_handles=set();seen_ids=set();times=[];cycles=[];lengths=set();total=0
    for key in keys:
        n=int.from_bytes(hex_bytes(key.get('public_modulus_hex'),'public modulus',256),'big')
        e=key.get('public_exponent');handle=key.get('handle','')
        require(n.bit_length()==2048 and n&1 and type(e) is int and e==65537 and n not in seen_n,
                'Invalid/reused RSA2048 public key')
        require(re.fullmatch('0x[0-9a-fA-F]{8}',handle) is not None and int(handle,16)!=0 and
                handle not in seen_handles and key.get('public_checks_pass') is True,
                'Invalid/reused key handle or failed public check')
        seen_n.add(n);seen_handles.add(handle)
        generation_id=key.get('generation_request_id')
        require(type(generation_id) is int and 0<generation_id<2**32 and generation_id not in seen_ids,
                'Missing/reused generation operation ID')
        seen_ids.add(generation_id)
        rounds=key.get('roundtrips',[])
        require(len(rounds)==per_key,'Incomplete per-key private sample set')
        for number,row in enumerate(rounds,1):
            require(row.get('case')==number,'Missing/reordered private case')
            message=hex_bytes(row.get('message_hex'),'message')
            returned=hex_bytes(row.get('returned_plaintext_hex'),'actual returned plaintext')
            cipher=hex_bytes(row.get('ciphertext_hex'),'ciphertext',256)
            require(len(message)<=240 and row.get('message_bytes')==len(message),'Invalid message length')
            # Independent frozen-frame construction/public arithmetic oracle.
            block=bytearray(256);block[1:5]=b'DE25';block[5:7]=len(message).to_bytes(2,'big')
            block[7:7+len(message)]=message
            representative=int.from_bytes(block,'big')
            require(representative<n and int.from_bytes(cipher,'big')==pow(representative,e,n),
                    'Recorded ciphertext disagrees with independent public encryption')
            require(row.get('actual_plaintext_match') is True and returned==message,
                    'Actual FPGA returned plaintext mismatch')
            require(row.get('expected_sha256')==hashlib.sha256(message).hexdigest() and
                    row.get('returned_sha256')==hashlib.sha256(returned).hexdigest(),
                    'Plaintext SHA record mismatch')
            ident=row.get('request_id')
            require(type(ident) is int and 0<ident<2**32 and ident not in seen_ids,'Missing/reused private operation ID')
            require(row.get('handle')==handle,'Private result attributed to the wrong key handle')
            seen_ids.add(ident);lengths.add(len(message));total+=1
            times.append(elapsed(row.get('private_decrypt_host_elapsed_s'),'private host elapsed seconds'))
            if row.get('worker_cycles64') is not None:
                count=row['worker_cycles64']
                require(type(count) is int and count>0 and row.get('worker_status')==0 and
                        row.get('worker_job_id')==ident,'Invalid/misattributed worker cycle sample')
                cycles.append(count)
    require(record.get('private_roundtrips_passed')==total==record.get('private_roundtrips_total'),
            'Private sample denominators disagree')
    require(not cycles or len(cycles)==total,'Partial worker cycle set must not imply complete core timing')
    result=dict(module='RSA private worker',headline_value=f'{total}/{total} FPGA RSA2048 private-decrypt cases',
        denominator=total,evidence_kind='HARDWARE',clock_hz=50000000,width_or_profile='RSA2048/e65537',
        source_revision=source,sof_sha256=sof,spi_hz=record['spi_hz'],key_count=len(keys),
        provider='FRESH_UNQUALIFIED',entropy_qualified=False,private_context_exported=False,
        method='Independent public-frame/pow oracle plus exact actual FPGA-returned plaintext across fresh generated contexts',
        observed_message_lengths=sorted(lengths),
        host_private_roundtrip_seconds=dict(minimum=min(times),median=statistics.median(times),maximum=max(times)),
        latency_window='Host request/response including SPI/polling/compute/cleanup; not core-only latency',
        limit='Artifact audit of lead-operated same-image hardware run; no entropy certification or factor-primality proof')
    if cycles:
        result['worker_cycles']=dict(count=len(cycles),minimum=min(cycles),median=statistics.median(cycles),maximum=max(cycles))
        result['worker_cycle_window']='Accepted private worker job through native engine close/scrub acknowledgment'
    else:result['worker_cycles']=None
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--keygen-evidence',type=Path,required=True)
    parser.add_argument('--phase1-evidence',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    record=json.loads(args.keygen_evidence.read_text(encoding='utf-8-sig'))
    phase1=json.loads(args.phase1_evidence.read_text(encoding='utf-8-sig'))
    result=audit(record,phase1)
    result['exact_log_path']=str(args.keygen_evidence.resolve())
    result['phase1_log_path']=str(args.phase1_evidence.resolve())
    result['input_sha256']={str(path.resolve()):hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in (args.keygen_evidence,args.phase1_evidence)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(result['headline_value']+' — HARDWARE record independently audited')


if __name__=='__main__':main()
