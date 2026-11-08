#!/usr/bin/env python3
"""Verify optional serial hooks preserve existing Juku machine code."""
import argparse, hashlib, json, subprocess, tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--assembler',type=Path,required=True);p.add_argument('--baseline',default='c1958b2');a=p.parse_args()
root=Path(__file__).resolve().parents[1]
results=[]
with tempfile.TemporaryDirectory() as tmp:
 t=Path(tmp)
 for version in ['legacy','c9']:
  binaries=[]
  for state in ['baseline','current']:
   d=t/(version+'-'+state);d.mkdir()
   for name in ['rom-abi.inc','rom-host-services.asm','netdisk-v3.asm']:
    data=subprocess.check_output(['git','show',a.baseline+':platform/'+name],cwd=root) if state=='baseline' else (root/'platform'/name).read_bytes()
    (d/name).write_bytes(data)
   source='        .8080\n        org 0\nROMHOSTSTATEBASE equ 08000h\nROMNETSTATEBASE equ 09000h\nROMNETDISK equ 1\n'
   if version=='c9':source+='ROM_ABI_C9 equ 1\n'
   for name in ['rom-abi.inc','rom-host-services.asm','netdisk-v3.asm']:source+=f'        include "{d/name}"\n'
   (d/'test.asm').write_text(source)
   subprocess.run([str(a.assembler.resolve()),'--zmac','-o',str(d/'test.cim'),str(d/'test.asm')],check=True)
   binaries.append((d/'test.cim').read_bytes())
  assert binaries[0]==binaries[1],version
  results.append(dict(profile=version,bytes=len(binaries[1]),sha256=hashlib.sha256(binaries[1]).hexdigest(),unchanged=True))
print(json.dumps(results,indent=2))
