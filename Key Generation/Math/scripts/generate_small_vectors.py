"""Exhaustive input domains on the unchanged32-bit datapath, not reduced-width RTL."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args()
rows=[];counts={}
def add(kind,n,x,y,result,status=0):
 hi=(result>>32)&0xffffffff if kind==2 else 0xbadbad02
 lo=result&0xffffffff
 rows.append((kind,n,x,y,lo,hi,status));counts[str(kind)]=counts.get(str(kind),0)+1
def basic(x,y):
 add(2,0,x,y,x*y);add(3,0,x,y,x+y);add(4,0,x,y,x-y)
 add(5,0,x,y,0xbadbad01,0x10 if x<y else 0x11 if x==y else 0x12)
for x in range(16):
 for y in range(16):basic(x,y)
 for kind,result in [(6,x>>1),(7,x),(8,0)]:add(kind,0,x,0,result)
boundaries=[0,1,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]
for x in boundaries:
 for y in boundaries:basic(x,y)
 for kind,result in [(6,x>>1),(7,x),(8,0)]:add(kind,0,x,0,result)
for n in range(3,32,2):
 inverse_r=pow(1<<32,-1,n)
 for x in range(n):
  for y in range(n):add(0,n,x,y,x*y*inverse_r%n)
  for exponent in range(16):add(1,n,x,exponent,pow(x,exponent,n))
# 2047=23*89 is composite, but is a strong pseudoprime to base2.
# Here n-1=2*1023, so the first modular exponent directly decides the round.
assert 2047==23*89 and pow(2,1023,2047)==1 and pow(3,1023,2047) not in (1,2046)
add(1,2047,2,1023,pow(2,1023,2047));add(1,2047,3,1023,pow(3,1023,2047))
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(str(len(rows))+'\n'+''.join(str(r[0])+' '+ ' '.join(f'{v:08x}' for v in r[1:])+'\n' for r in rows))
a.output.with_suffix('.json').write_text(json.dumps({'cases':len(rows),'kind_counts':counts,'oracle':'Python arbitrary precision operators, pow(base, exponent, modulus), pow(R,-1,modulus)','datapath_limb_bits':32,'exhaustive_binary_input_bits':4,'odd_moduli':list(range(3,32,2)),'exponent_domain':[0,15],'pseudoprime':{'n':2047,'factors':[23,89],'base2_pow':pow(2,1023,2047),'base3_pow':pow(3,1023,2047),'scope':'Arithmetic example, not an accepted RSA candidate; trial division rejects23 and89.'},'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest()},indent=2)+'\n')
print(f'Generated {len(rows)} independent small-domain cases')
