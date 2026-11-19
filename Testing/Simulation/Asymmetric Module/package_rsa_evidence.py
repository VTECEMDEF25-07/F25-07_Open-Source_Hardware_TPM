"""Audit frozen acceptance inputs and package review evidence; never invent PASS.

Native jobs must finish first. Enabled fit failure is retained as a material
limit, while every functional job below must have an explicit completion marker.
"""
import hashlib
import json
from pathlib import Path
import subprocess


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    root=Path(__file__).resolve().parents[3]
    out=Path(__file__).with_name('evidence');out.mkdir(exist_ok=True)
    definitions={
        'generic_adapter':root/'build/rsa-fast-adapter/evidence.json',
        'generated_slot':root/'build/rsa-fast-generated/evidence.json',
        'generic_boundary':root/'build/rsa-fast-boundary/evidence.json',
        'generic_errors':root/'build/rsa-fast-errors/evidence.json',
        'generic_reset':root/'build/rsa-fast-reset/evidence.json',
        'generic_protected_d':root/'build/rsa-protected-d/evidence.json',
        'no_reset_private_retry':root/'build/rsa-retry/evidence.json',
        'vendor_compile':root/'build/rsa-native-vendor/compile.json',
        'vendor_boundary':root/'build/rsa-native-vendor/boundary.json',
        'vendor_protected_d':root/'build/rsa-native-vendor/protected-d.json',
        'vendor_adapter':root/'build/rsa-native-vendor/adapter.json',
        'host_regression':root/'build/rsa-final-regression/regression-0.json',
        'slot_boundary_generic':root/'build/rsa-final-lifecycle/boundary-0.json',
        'slot_boundary_vendor':root/'build/rsa-final-lifecycle/boundary-1.json',
        'real_rng_generic':root/'build/rsa-final-lifecycle/real-0.json',
        'real_rng_vendor':root/'build/rsa-final-lifecycle/real-1.json',
        'real_health_generic':root/'build/rsa-final-lifecycle/health-0.json',
        'real_health_vendor':root/'build/rsa-final-lifecycle/health-1.json',
        'enabled_cyclone_synthesis':root.parent/'rsac1/evidence.json',
        'enabled_agilex_fit_attempt':root.parent/'rsaa1/evidence.json'}
    records={};audited=set()
    for name,path in definitions.items():
        record=json.loads(path.read_text())
        if name=='vendor_compile':
            assert len(record['commands'])>=5 and all(c['returncode']==0 for c in record['commands']),name
        elif name.startswith('enabled_'):
            if name=='enabled_cyclone_synthesis':assert record['result']=='PASS',name
        else:
            assert record.get('pass_markers'),name+' missing explicit PASS'
            assert all(c['returncode']==0 for c in record['commands']),name
        inputs=record.get('inputs',record.get('source_hashes',{}))
        if 'inputs_after' in record:assert inputs==record['inputs_after'],name+' changed during run'
        for relative,expected in inputs.items():
            source=root/relative
            assert source.is_file() and sha(source)==expected,name+' stale input: '+relative
            audited.add(source)
        actual_logs={sha(p) for p in path.parent.glob('*.log')}
        # Both native and fast runners retain an SHA256 for each tool transcript.
        commands=record.get('commands',[{'sha256':record.get('transcript_sha256')}])
        for command in commands:
            expected=command.get('sha256',command.get('transcript_sha256'))
            assert expected in actual_logs,name+' transcript changed or missing'
        records[name]=record
    markers=records['generated_slot']['pass_markers']
    assert any('exact_slot_words=129 source_words=384 operations=2' in p for p in markers)
    assert 'TPM_LEGACY_SPI_PASS entry=240 errors=0' in records['host_regression']['pass_markers']
    default=root/'build/rsa-default-pair'
    log=default/'result.log'
    text=log.read_text()
    assert 'PASS pair check: 8 vectors' in text
    default_sources=[root/'Testing/Simulation/Key Generation/testbench/tb_keygen_pair_check.sv',
        root/'Testing/Simulation/Key Generation/scripts/test_pair_verilator.sh',
        root/'Testing/Simulation/Key Generation/reference/pair_vectors.py',
        root/'Testing/Simulation/Key Generation/reference/expected_keys.json']
    audited.update(default_sources)
    default_record={'pass_markers':[line for line in text.splitlines() if 'PASS' in line],
        'inputs':{str(p.relative_to(root)):sha(p) for p in default_sources},
        'logs':{p.name:sha(p) for p in default.glob('*.log')},
        'fixture_sha256':sha(default/'pair_vectors.mem'),
        'vector_cycle_deadline':10000000,
        'external_wall_deadline_seconds':None}
    fitdir=definitions['enabled_agilex_fit_attempt'].parent
    reports={}
    for pattern in ['*.syn.summary','*.fit.summary','*.sta.summary']:
        for path in (fitdir/'output_files').glob(pattern):
            reports[path.name]={'sha256':sha(path),'text':path.read_text(errors='replace')}
    if (fitdir/'output_files/consumer.fit.plan.rpt').exists():
        path=fitdir/'output_files/consumer.fit.plan.rpt'
        reports[path.name]={'sha256':sha(path)}
    aggregate={'source_checkpoint':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip(),
        'dependency':{'pr':58,'head':'8dc74f9f9b673eee45e9f7d96aa37322490ce8ff','eventual_target':'develop'},
        'full_rsa_width':2048,'new_host_commands':0,'host_variants':17,'legacy_entries':240,'legacy_errors':0,
        'jobs':records,'default_pair':default_record,'enabled_agilex_reports':reports,
        'enabled_agilex_fit_completed':records['enabled_agilex_fit_attempt']['result']=='PASS',
        'enabled_agilex_fit_deadline_hit':records['enabled_agilex_fit_attempt']['elapsed_seconds']>=records['enabled_agilex_fit_attempt']['deadline_seconds'],
        'fitted_timing_available':any('.sta.summary' in name for name in reports),
        'audited_input_count':len(audited),
        'candidate_inputs':{str(p.relative_to(root)):sha(p) for p in sorted(audited)},
        'board_signoff':False,'hardware_programmed':False,'physical_entropy_qualified':False,
        'notes':['Generic generated-slot acceptance is full width and uses real keygen, not a prefilled slot.',
            'Vendor adapter includes real Altera derivation models, but full numerical generation-to-consumer is Generic only.',
            'Enabled fit is a virtual-pin harness with external random input, not the board TPM/entropy image.',
            'Synthesis/compile completion does not imply timing closure; inspect retained fit/STA results.',
            'Final documentation/evidence commits must preserve every candidate input byte.']}
    destination=out/'rsa_protected_consumer_20261118.json'
    destination.write_text(json.dumps(aggregate,indent=2)+'\n')
    print('RSA_EVIDENCE_AUDIT_PASS inputs='+str(len(audited))+' sha256='+sha(destination),flush=True)


if __name__=='__main__':main()
