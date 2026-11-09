"""Physical fresh RSA-2048 timing batch; persist timings and public digests only."""
import argparse,hashlib,json,math,os,statistics,time
from pathlib import Path
from pyftdi.spi import SpiController
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Simulation/Key Generation/reference'))
from key_checker import check_key

p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--count',type=int,default=1000)
a=p.parse_args();B=a.bundle
if not 1<=a.count<=1000:raise ValueError('count must be 1..1000')
manifest=json.loads((B/'source-manifest.json').read_text());clock=manifest['clock_hz']
expected=json.loads((B/'expected_hashes.json').read_text())['results']
seeds=json.loads((B/'seeds.json').read_text())['seeds']
destination=B/'batch-results.json'
if destination.exists():raise RuntimeError('Existing batch result: refusing to overwrite or silently resume')
report={'status':'RUNNING','requested_fresh_keys':a.count,'completed_fresh_keys':0,'clock_hz':clock,'spi_hz':100000,'fingerprint':manifest['fingerprint'],'revision':manifest['revision'],'source':'physical-ring-Hash_DRBG','rsa_bits':2048,'independent_primality_bases_per_prime':64,'qualification':[],'results':[],'test_only':True,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
ctrl=None;unique=set();fixture_moduli=set();public_product=1;active_index=None;trace_baseline=None

def summary(rows):
    if not rows:return {'count':0}
    values=[r['total_core_plus_setup_seconds'] for r in rows]
    ordered=sorted(values)
    return {'count':len(rows),'mean_seconds':statistics.mean(values),'median_seconds':statistics.median(values),'min_seconds':ordered[0],'max_seconds':ordered[-1],'p95_seconds':ordered[math.ceil(.95*len(values))-1],'sample_stdev_seconds':statistics.stdev(values) if len(values)>1 else None,'mean_core_only_seconds':statistics.mean(r['core_seconds'] for r in rows),'all_independent_checks_pass':all(r['independent_key_check']=='PASS' for r in rows)}

def save():
    report['completed_fresh_keys']=len(report['results']);report['summary']=summary(report['results'])
    report['updated_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())
    temp=destination.with_suffix('.json.tmp');temp.write_text(json.dumps(report,indent=2)+'\n');os.replace(temp,destination)
    progress={'status':report['status'],'clock_hz':clock,'requested_fresh_keys':a.count,'completed_fresh_keys':len(report['results']),'qualification_completed':len(report['qualification']),'summary':report['summary'],'updated_utc':report['updated_utc']}
    if report['results']:
        progress['last_key_seconds']=report['results'][-1]['total_core_plus_setup_seconds']
        progress['estimated_remaining_wall_seconds']=(a.count-len(report['results']))*statistics.mean(r['wall_seconds_to_status']+r['result_download_seconds']+r['independent_check_seconds'] for r in report['results'])
    if 'error' in report:progress['error']=report['error']
    temp=B/'batch-progress.json.tmp';temp.write_text(json.dumps(progress,indent=2)+'\n');os.replace(temp,B/'batch-progress.json')

def require(condition,message):
    if not condition:raise RuntimeError(message)

def read(addr):
    raw=bytes(port.exchange(bytes([1,addr,0,0,0,0,0,0]),duplex=True))
    require(raw[:4]==b'\xa5\0\0\0' and len(raw)==8,'SPI framing failure')
    return int.from_bytes(raw[4:],'big')

def write(addr,value):
    raw=bytes(port.exchange(bytes([2,addr,0,0])+value.to_bytes(4,'big'),duplex=True))
    require(raw[:4]==b'\xa5\0\0\0' and len(raw)==8,'SPI framing failure')

def wait_ready():
    deadline=time.monotonic()+10
    while not read(3)&1:
        if time.monotonic()>deadline:raise TimeoutError('core admission')
        time.sleep(.01)

def cooling():
    t=read(13);rpm=read(14)&65535;status=read(15);temp=(t>>16)&65535
    if temp&32768:temp-=65536
    sample={'fpga_c':temp,'board_c':t&65535,'fan_rpm':rpm,'status':status}
    # Alarm 0x08 is the already documented GPIO1 full-on override; leave it on.
    acceptable=(status>>8)&1==1 and status&255 in (0,8) and 5<=temp<75 and rpm>=1000
    if not acceptable:
        report['cooling_failure']=sample
        raise RuntimeError('Cooling telemetry outside the accepted bounds')
    return sample

def reset_trace():
    require(read(54)==0x52535431,'Reset trace image identity mismatch')
    return dict(zip(['pll_losses','spi_resets','board_resets','core_resets','uptime_ms'],[read(i) for i in range(48,53)]))

def check_reset_trace():
    current=reset_trace()
    if trace_baseline is not None:
        changed=any(current[k]!=trace_baseline[k] for k in ['pll_losses','spi_resets','board_resets','core_resets'])
        if changed or current['uptime_ms']<trace_baseline['uptime_ms']:
            report['reset_interruption']={'baseline':trace_baseline,'current':current,'request_id':read(5)}
            raise RuntimeError('Unexpected reset/PLL event; batch stopped without retrying or dropping a sample')
    return current

def job(mode,index,seed_index=0):
    global public_product
    check_reset_trace();wait_ready();write(11,0);require(read(11)==0,'Unexpected test-control injection')
    write(40,mode);write(4,2);write(5,index)
    require(read(40)==mode and read(4)==2 and read(5)==index,'Request mode/profile/ID readback mismatch')
    if not mode:
        seed=bytes.fromhex(seeds[seed_index]['seed_hex'])
        for i in range(8):write(16+i,int.from_bytes(seed[i*4:i*4+4],'big'))
    if not mode:
        require(all(read(16+i)==int.from_bytes(seed[i*4:i*4+4],'big') for i in range(8)),'Fixture seed readback mismatch')
    print('RUN',mode,index,flush=True)
    before=cooling();peak_temp=before['fpga_c'];min_rpm=before['fan_rpm']
    wall=time.monotonic();next_cooling=wall+1;next_debug=wall;write(2,1)
    while True:
        status=read(3)
        if status&8:break
        now=time.monotonic()
        if status&1 and now-wall>.25:
            report['idle_interruption']={'index':index,'mode':mode,'request_id':read(5),'trace':reset_trace()}
            raise RuntimeError('Core returned to idle before a valid result')
        if now>=next_debug:
            current_trace=check_reset_trace()
            require(read(5)==index,'Request context changed while running')
            snapshot={'reset_trace':current_trace,'mode':mode,'index':index,'elapsed_seconds':round(now-wall,2),'status':status,'system_state':read(12),'cycles':read(6)+(read(7)<<32),'generation_words':read(41),'setup_cycles':read(44),'entropy_blocks':read(45)}
            (B/'diagnostic-current.json').write_text(json.dumps(snapshot,indent=2)+'\n')
            print('COUNTERS',json.dumps(snapshot),flush=True)
            next_debug=now+(5 if not mode else 60)
        if now-wall>(120 if not mode else 1800):raise TimeoutError('RSA qualification or generation deadline; batch stopped without dropping samples')
        if now>=next_cooling:
            sample=cooling();peak_temp=max(peak_temp,sample['fpga_c']);min_rpm=min(min_rpm,sample['fan_rpm']);next_cooling=now+1
        time.sleep(.1)
    wall_to_status=time.monotonic()-wall
    require((status>>8)&15==0,'RSA core returned nonzero status')
    cycles=read(6)+(read(7)<<32);setup_cycles=read(44);count=read(47)
    require(count==129,'RSA output word count')
    start=time.monotonic();words=[]
    for i in range(count):write(8,i);words.append(read(9))
    download_seconds=time.monotonic()-start
    def integer(part):return int.from_bytes(b''.join(w.to_bytes(4,'big') for w in part),'big')
    n=integer(words[:64]);e=words[64];prime_p=integer(words[65:97]);prime_q=integer(words[97:129])
    start=time.monotonic();lam=math.lcm(prime_p-1,prime_q-1)
    check_key({'n':n,'e':e,'p':prime_p,'q':prime_q,'d':pow(e,-1,lam)})
    check_seconds=time.monotonic()-start
    words_used=read(41)
    require(cycles>0 and words_used>0,'Empty generation counters')
    if mode:
        require(read(42)>0 and read(45)>0,'Fresh DRBG/entropy counters did not advance')
    if not mode:
        require(hashlib.sha256(b''.join(x.to_bytes(4,'big') for x in words)).hexdigest()==expected[seed_index]['output_sha256'],'Fixture full-output digest mismatch')
        require(words_used==expected[seed_index]['words_consumed'],'Fixture generation-word count mismatch')
    public_digest=hashlib.sha256(n.to_bytes(256,'big')).hexdigest()
    if mode:
        require(public_digest not in unique,'Duplicate public modulus; batch stopped')
        require(public_digest not in fixture_moduli,'Fresh result equals a public fixture')
        require(math.gcd(public_product,n)==1,'Shared RSA factor across generated keys; batch stopped')
        unique.add(public_digest)
        public_product*=n
    else:
        fixture_moduli.add(public_digest)
    after_trace=check_reset_trace()
    after=cooling();peak_temp=max(peak_temp,after['fpga_c']);min_rpm=min(min_rpm,after['fan_rpm'])
    item={'reset_trace_after':after_trace,'index':index,'source_mode':mode,'core_cycles':cycles,'setup_cycles':setup_cycles,'core_seconds':cycles/clock,'total_core_plus_setup_seconds':(cycles+setup_cycles)/clock,'wall_seconds_to_status':wall_to_status,'result_download_seconds':download_seconds,'independent_check_seconds':check_seconds,'generation_words':words_used,'drbg_blocks':read(42),'drbg_busy_cycles':read(43),'entropy_blocks_observed':read(45),'public_modulus_sha256':public_digest,'independent_key_check':'PASS','peak_fpga_c':peak_temp,'minimum_fan_rpm':min_rpm,'cooling_before':before,'cooling_after':after}
    # Private factors are never included in a persisted result or log.
    del words,prime_p,prime_q,lam,n
    write(2,2);wait_ready()
    return item

try:
    ctrl=SpiController(cs_count=1);ctrl.configure('ftdi://ftdi:232h:FTA6H280/1',direction=0x10,initial=0x18)
    port=ctrl.get_port(cs=0,freq=100000,mode=0)
    ctrl.get_gpio().write(0);time.sleep(.03);ctrl.get_gpio().write(0x10);time.sleep(.05)
    require(read(0)==0x48575031 and read(1)==0x48575031,'Benchmark image identity')
    require(''.join(f'{read(i):08x}' for i in range(24,32))==manifest['fingerprint'],'Benchmark source fingerprint mismatch')
    require(read(46)==manifest.get('clock_register_hz',round(clock)),'Nominal benchmark clock register mismatch')
    write(63,0x5a1793c2);require(read(63)==0x5a1793c2,'SPI readback mismatch')
    deadline=time.monotonic()+30
    while True:
        try:report['cooling_initial']=cooling();break
        except RuntimeError:
            if time.monotonic()>deadline:raise
            time.sleep(1)
    trace_baseline=reset_trace();report['reset_baseline']=trace_baseline
    save()
    for i in range(3):
        item=job(0,10001+i,i);report['qualification'].append(item);save()
        print('FIXTURE PASS',i+1,round(item['core_seconds'],6),flush=True)
    report['batch_started_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());save()
    for index in range(1,a.count+1):
        active_index=index;item=job(1,index);report['results'].append(item);save()
        print('KEY',index,'OF',a.count,'SECONDS',round(item['total_core_plus_setup_seconds'],6),'MEAN',round(report['summary']['mean_seconds'],6),'TEMP',item['peak_fpga_c'],'RPM',item['minimum_fan_rpm'],flush=True)
    require(len(report['results'])==a.count and len(unique)==a.count,'Incomplete count or modulus uniqueness')
    report['status']='PASS';report['no_shared_factors']=True;report['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());save()
except BaseException as error:
    
    try:
        report['ftdi_gpio_at_failure']=ctrl.get_gpio().read(with_output=True)
        report['reset_trace_at_failure']=reset_trace()
    except Exception as diagnostic_error:report['reset_trace_error']=str(diagnostic_error)
    report['status']='FAIL';report['failed_index']=active_index;report['error']=type(error).__name__+': '+str(error);save();raise
finally:
    if ctrl:
        try:ctrl.get_gpio().write(0)
        finally:ctrl.terminate()
