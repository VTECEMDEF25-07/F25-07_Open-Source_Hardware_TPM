# Filename: generate_vectors.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Independent Python integer oracle. No RTL algorithm is reimplemented.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Independent Python integer oracle. No RTL algorithm is reimplemented."""
import argparse, random
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('--full',action='store_true');p.add_argument('--max-limbs',type=int,default=64);a=p.parse_args()
r=random.Random(0x52ca1913)
cases=[]
for n in [x for x in [1,2,4,8,32,64] if x <= a.max_limbs]:
    for j in range(3):
        modulus=r.getrandbits(n*32) | (1 << (n*32-1)) | 1
        left=r.randrange(modulus); right=r.randrange(modulus)
        cases.append((0,n,n,modulus,left,right,left*right*pow(1 << (n*32),-1,modulus)%modulus))
        cases.append((2,n,n,modulus,left,right,left*right))
for n in [1,2,8,32]:
    modulus=r.getrandbits(n*32) | (1 << (n*32-1)) | 1
    left=r.randrange(modulus); exponent=65537
    cases.append((1,n,1,modulus,left,exponent,pow(left,exponent,modulus)))
for exponent in [0,1,2,0xffffffff]:
    for left in [0,1,2]:
        cases.append((1,1,1,3,left,exponent,pow(left,exponent,3)))
if a.full:
    for j in range(2):
        n=32;modulus=r.getrandbits(1024)|(1<<1023)|1
        left=r.randrange(modulus);exponent=r.getrandbits(1024)
        cases.append((1,n,n,modulus,left,exponent,pow(left,exponent,modulus)))
with Path(a.output).open('w') as f:
    f.write(str(len(cases))+'\n')
    for kind,n,en,m,x,y,z in cases:
        f.write(f'{kind} {n} {en}\n')
        for value,count in [(m,n),(x,n),(y,en if kind==1 else n),(z,2*n if kind==2 else n)]:
            f.write(' '.join(f'{(value>>(32*i))&0xffffffff:08x}' for i in range(count))+'\n')
print(f'Generated {len(cases)} independent bigint cases')
