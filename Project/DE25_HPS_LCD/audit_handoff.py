"""Audit generated DE25 collateral and emit firmware masks/offsets from facts.

No Quartus invocation, board access or fabricated SDM binary handoff.
"""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent
SVD=Path('C:/altera_pro/26.1/riscfree/xsvd/agilex5_hps.svd')
chip=ET.parse(SVD).getroot()
ipdir=HERE/'ip/hps_lcd_subsys/hps_lcd_subsys_agilex_hps'
xml=ipdir/'hps_lcd_subsys_agilex_hps.xml'
params={x.get('name'):x.get('value') for x in ET.parse(xml).findall('.//parameter')}
qip=(ipdir/'hps_lcd_subsys_agilex_hps.qip').read_text()
data=re.search(r'-name HPS_ISW_DATA "([^"]+)"',qip).group(1)
regs={k:int(v) for k,v in re.findall(r'\bpll (\S+) (\d+)',data)}
selects={int(k):int(v) for k,v in re.findall(r'\bsel (\d+) (\d+)',data)}
assert len(selects)==48
assert {k:v for k,v in selects.items() if v!=8}=={27:9,38:5,39:5,43:7,44:7,45:7}
assert 'SDM DDR 0' in data and 'intfcsel f2soc 0 intfcsel f2sdram 0' in data
for name in ['H2F_Width','LWH2F_Width','f2s_data_width','f2sdram_data_width']:
    assert int(params[name])==0,(name,params[name])
assert params['EMIF_AXI_Enable'].lower() in ['false','0']
assert params['MPFE_is_present'].lower() in ['false','0']
use=re.findall(r'\buse (\S+) (\d+)',data)
assert len(use)==22 and all(int(v)==0 for k,v in use)
assert not re.findall(r'\b(?:din|dou) \d+ [1-9]\d*',data)
pins=dict(re.findall(r'HPS_LOCATION PIN_(\S+) .*?-to (\w+)',qip))
expected_pins={'T124':'hps_io_gpio34','P124':'hps_io_gpio35','H127':'hps_io_gpio42','AG123':'hps_io_hps_osc_clk','AB127':'hps_io_uart1_rx','M124':'hps_io_uart1_tx','F127':'hps_io_spim0_clk','Y124':'hps_io_spim0_mosi','AB124':'hps_io_spim0_ss0_n'}
assert pins==expected_pins
assert qip.count('-name IO_STANDARD "1.8 V"')==9
clockp=next(p for p in chip.findall('.//peripheral') if p.findtext('name')=='i_clk_mgr')
clockregs={int(r.findtext('addressOffset'),0):r for r in clockp.findall('.//register')}
pinp=next(p for p in chip.findall('.//peripheral') if p.findtext('name')=='i_dedio_pinmux')
pinregs={r.findtext('name'):int(r.findtext('addressOffset'),0) for r in pinp.findall('.//register')}
clock_order=[('mainpllgrp.nocclk',0x40),('mainpllgrp.nocdiv',0x44),
 ('mainpllgrp.pllglob',0x48),('mainpllgrp.fdbck',0x4c),
 *[(f'mainpllgrp.pllc{i}',0x5c+4*i) for i in range(4)],
 ('mainpllgrp.pllm',0x6c),('perpllgrp.emacctl',0x94),('perpllgrp.gpiodiv',0x98),
 ('perpllgrp.pllglob',0x9c),('perpllgrp.fdbck',0xa0),
 *[(f'perpllgrp.pllc{i}',0xb0+4*i) for i in range(4)],('perpllgrp.pllm',0xc0)]
clock_order += [(f'ctl.{n}',off) for n,off in [
 ('emacactr',0xd4),('emacbctr',0xd8),('emacptpctr',0xdc),('gpiodbctr',0xe0),
 ('s2fuser0ctr',0xe8),('s2fuser1ctr',0xec),('psirefctr',0xf0),('usb31ctr',0xf8),
 ('dsuctr',0xfc),('core01ctr',0x100),('core23ctr',0x104),('core2ctr',0x108),('core3ctr',0x10c)]]
words=[]
for name,offset in clock_order:
    value=mask=0
    # Unused Ethernet/USB/user-clock/debounce counters are neither programmed
    # nor interpreted by LCD firmware. Their SVD fields vary across revisions.
    if name.startswith('ctl.') and offset<0xfc:
        words.append(dict(name=name,offset=offset,value=0,mask=0,allowed=0xffffffff))
        continue
    fields={f.findtext('name'):f for f in clockregs[offset].findall('.//field')}
    for reg,val in regs.items():
        if not reg.startswith(name+'.'):continue
        field=reg[len(name)+1:]
        if field=='fstrefclk':field='fastrefclk' # Tool's per-PLL ISW spelling.
        assert field in fields,(name,field,list(fields))
        f=fields[field];lo=int(f.findtext('lsb'));hi=int(f.findtext('msb'))
        assert val<1<<(hi-lo+1)
        value|=val<<lo;mask|=((1<<(hi-lo+1))-1)<<lo
    assert mask
    extra=(0x30000003 if name.endswith('pllglob') else 0x08000000 if '.pllc' in name else 0)
    words.append(dict(name=name,offset=offset,value=value,mask=mask,allowed=mask|extra))
assert len(words)==31
for name in ['hps_osc_clk_hz','fpga_clk_hz']:
    words.append(dict(name=name,offset=0,value=regs[name],mask=0xffffffff,allowed=0xffffffff))
offsets={
 'sel':[pinregs[f'pin{i}sel'] for i in range(48)],
 'io':[pinregs[f'io{i}ctrl']-0x130 for i in range(48)],
 'delay':[pinregs[f'io{i}_delay']-0x400 for i in range(48)],
 'fpga':sorted(pinregs[k]-0x300 for k in pinregs if k.startswith('pinmux_') and k.endswith('_usefpga'))}
assert len(offsets['fpga'])==22
header=['/* Generated from actual Pro26.1 QIP + installed SVD; do not edit. */','#ifndef DE25_HANDOFF_FACTS_H','#define DE25_HANDOFF_FACTS_H','#include <stdint.h>','struct clock_fact {uint32_t offset,value,mask,allowed;};','static const struct clock_fact clock_facts[33]={']
header += [f'{{0x{w["offset"]:x}U,0x{w["value"]:08x}U,0x{w["mask"]:08x}U,0x{w["allowed"]:08x}U}}, /* {w["name"]} */' for w in words]
header+=['};']
for name,values in offsets.items():header += [f'static const uint16_t {name}_offsets[{len(values)}]={{'+','.join(f'0x{x:x}' for x in values)+'};']
header+=['static const uint8_t expected_pinsel[48]={'+','.join(str(selects[i]) for i in range(48))+'};','#endif']
fw=HERE.parents[1]/'Source Code/Display/firmware'
fw.mkdir(parents=True,exist_ok=True)
(fw/'de25_handoff_facts.h').write_text('\n'.join(header)+'\n',newline='\n')
files=[HERE/'generate_hps_lcd.tcl',HERE/'audit_handoff.py',HERE/'hps_lcd_subsys.qsys',HERE/'ip/hps_lcd_subsys/hps_lcd_subsys_agilex_hps.ip',xml,ipdir/'hps_lcd_subsys_agilex_hps.qip',HERE/'hps_lcd_subsys/synth/hps_lcd_subsys.v',HERE.parents[1]/'Source Code/Display/hps_lcd_island.v',SVD]
report=dict(tool='Quartus Pro26.1 build110 / intel_agilex_5_soc14.0.0',device='A5ED013BB32AE4SCS',pins=pins,clock_words=words,pin_offsets=offsets,options=params['HPS_HANDOFF_OPTION_STRING'],source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
 scope='Generated IP handoff metadata verified offline; fitted SDM binary not yet available; no fit or target test')
(HERE/'handoff_audit.json').write_text(json.dumps(report,indent=2))
(HERE/'hps_handoff.txt').write_text(params['HPS_HANDOFF_STRING'])
(HERE/'derived_parameters.json').write_text(json.dumps(params,indent=2))
print(json.dumps({k:v for k,v in report.items() if k in ['tool','device','pins','options','scope']},indent=2))
