#!/usr/bin/env python3
"""Interactive DEMO-ONLY laptop encryption / FPGA AES and RSA private decryption.

Hardware lead alone operates this client until final acceptance. Existing Phase I
hardware evidence must bind the same exact image. No key or board is synthesized
by software, and no host RSA private operation exists in the customer path.
"""
from __future__ import annotations
import argparse,importlib,json,os,queue,threading,time
from pathlib import Path
from de25_customer_crypto import aes_encrypt_on_laptop,expected_cfb_final_iv
from de25_customer_console import PublicRecorder,input_message,show_bytes
from de25_customer_evidence import load_phase1,display_phase1,validate_phase1
from de25_customer_protocol import CustomerClient,ProtocolError

DEFAULT_MESSAGE='Hello Lenovo — encrypted on the laptop, decrypted by the DE25.'


def while_waiting_for_input(function,transport):
    """Only main thread touches D2XX; keyboard wait must not starve actual LCD status."""
    result=queue.Queue(maxsize=1)
    def read():
        try: result.put((True,function()))
        except BaseException as exc: result.put((False,exc))
    threading.Thread(target=read,daemon=True).start()
    while True:
        try:
            ok,value=result.get(timeout=.25)
            if not ok: raise value
            return value
        except queue.Empty: transport.poll_status(force=True)


def install_status_callback(transport,recorder,provider,status_relay=None):
    observed=[]; last_sequence=None
    def callback(snapshot):
        nonlocal last_sequence
        # A relay gets genuine duplicate snapshots as liveness heartbeats, never invented progress.
        public={k:snapshot[k] for k in ('status_word','operation_id','sequence')}
        if status_relay is not None: status_relay(public)
        if snapshot['sequence']!=last_sequence:
            recorder.actual_status(snapshot['state'],snapshot['operation_id'],snapshot['detail'],snapshot['provider'])
            observed.append(dict(snapshot)); last_sequence=snapshot['sequence']
    transport.expected_provider=provider
    transport.status_callback=callback
    return observed


def run_customer_flow(client,recorder,phase1,allow_export,auto=False,message=DEFAULT_MESSAGE,
                      rsa_message=None,status_relay=None):
    if not allow_export:
        raise ValueError('This flow requires explicit --allow-demo-key-export acknowledgment')
    phase1=validate_phase1(phase1,phase1.get('sof_sha256',''))
    display_phase1(phase1,recorder)
    recorder.emit('scope','DEMO ONLY — disposable AES key exported to laptop; RSA private key stays on FPGA.',
                  aes_export_authorized=True,rsa_private_export=False)
    recorder.emit('scope','RSA uses a bounded educational raw encoding; not OAEP/PKCS encryption.')
    statuses=install_status_callback(client.transport,recorder,client.provider,status_relay)
    client.startup(); caps=client.capabilities()
    recorder.emit('capabilities','FPGA capabilities: AES256 / real RSA2048 private operation / actual hardware status.',
                  provider='FRESH_UNQUALIFIED' if client.provider==0 else 'TEST_DETERMINISTIC',
                  aes_bits=caps.aes_bits,rsa_bits=caps.rsa_bits,core_hz=caps.core_hz,
                  entropy_qualified=False)
    if client.provider:
        recorder.emit('test-warning','TEST_DETERMINISTIC selected explicitly — not a fresh customer hardware acceptance run.')
    if not hasattr(client.transport,'poll_status'):
        raise ProtocolError('Customer transport must support actual hardware status polling')
    if client.transport.poll_status(force=True) is None and not statuses:
        raise ProtocolError('Actual FPGA status is unavailable; refusing host-invented progress')

    recorder.emit('aes-keygen-submit','AES: requesting a fresh FPGA-generated disposable 256-bit key.')
    aes_start=time.monotonic(); aes_handle,key=client.generate_aes_export(allowed=True)
    aes_gen_s=time.monotonic()-aes_start
    recorder.emit('aes-keygen-complete',f'AES: FPGA key committed as handle 0x{aes_handle:08X}; 32 DEMO key bytes delivered to laptop (not printed).',
                  handle=aes_handle,key_bytes=32,generation_s=aes_gen_s)
    try:
        plaintext=input_message('AES message',1024,message) if auto else while_waiting_for_input(
            lambda:input_message('AES message',1024),client.transport)
        recorder.emit('aes-message','AES message: '+show_bytes(plaintext),plaintext=plaintext.decode('utf-8'),utf8_bytes=len(plaintext))
        iv=os.urandom(16)
        ciphertext=aes_encrypt_on_laptop(bytes(key),iv,plaintext)
        recorder.emit('aes-laptop-encrypt',f'LAPTOP encrypted with AES256-CFB: {ciphertext.hex()[:96]}'+('...' if len(ciphertext)>48 else ''),
                      ciphertext_hex=ciphertext.hex(),iv_hex=iv.hex(),location='laptop')
        recorder.emit('aes-fpga-decrypt-submit','FPGA: decrypting the laptop ciphertext using its retained AES key.')
        dec_start=time.monotonic(); returned,ivout=client.decrypt_aes(aes_handle,iv,ciphertext)
        aes_dec_s=time.monotonic()-dec_start
        if returned!=plaintext or ivout!=expected_cfb_final_iv(ciphertext,iv):
            raise ProtocolError('FPGA AES plaintext or final IV does not match the actual laptop message/ciphertext')
        recorder.emit('aes-fpga-plaintext','FPGA returned AES plaintext: '+show_bytes(returned),
                      returned_plaintext=returned.decode('utf-8'),plaintext_match=True,final_iv_match=True,
                      final_iv_hex=ivout.hex(),decrypt_s=aes_dec_s,location='FPGA')
        recorder.emit('aes-pass','AES: laptop encryption -> FPGA decryption -> exact plaintext match PASS.')
        aes_result=dict(handle=f'0x{aes_handle:08x}',message=plaintext.decode('utf-8'),ciphertext_hex=ciphertext.hex(),
                        initial_iv_hex=iv.hex(),final_iv_hex=ivout.hex(),returned_plaintext=returned.decode('utf-8'),
                        plaintext_match=True,iv_match=True,generation_s=aes_gen_s,decrypt_s=aes_dec_s,
                        disposable_key_exported=True,key_value_recorded=False)
    finally:
        # Best effort mutable host-copy clearing; no secure-erasure claim for Python/library copies.
        key[:]=bytes(len(key)); del key

    if not auto: while_waiting_for_input(lambda:input('Press Enter to generate the RSA key pair on the FPGA... '),client.transport)
    recorder.emit('rsa-keygen-submit','RSA: requesting a real RNG-driven RSA2048 key pair on the FPGA. Waiting for actual hardware completion...')
    rsa_start=time.monotonic(); rsa_handle,public=client.generate_rsa_public()
    rsa_gen_s=time.monotonic()-rsa_start
    nhex=public.modulus.to_bytes(256,'big').hex()
    recorder.emit('rsa-keygen-complete',f'FPGA RSA public key: n[2048]={nhex[:64]}...; e={public.exponent}. Private context stays on FPGA.',
                  handle=rsa_handle,modulus_hex=nhex,public_exponent=public.exponent,
                  generation_s=rsa_gen_s,private_context_exported=False)
    rsa_plain=input_message('RSA message',240,rsa_message if rsa_message is not None else message) if auto else while_waiting_for_input(
        lambda:input_message('RSA message',240),client.transport)
    recorder.emit('rsa-message','RSA message: '+show_bytes(rsa_plain),plaintext=rsa_plain.decode('utf-8'),utf8_bytes=len(rsa_plain))
    rsa_cipher=public.encrypt_on_laptop(rsa_plain)
    recorder.emit('rsa-laptop-public-encrypt',f'LAPTOP encrypted with the FPGA public key: {rsa_cipher.hex()[:96]}...',
                  ciphertext_hex=rsa_cipher.hex(),location='laptop',operation='public encryption')
    recorder.emit('rsa-fpga-private-decrypt-submit','FPGA: private-key decryption, frame validation and actual plaintext extraction.')
    rsa_dec_start=time.monotonic(); rsa_returned=client.decrypt_rsa(rsa_handle,rsa_cipher)
    rsa_dec_s=time.monotonic()-rsa_dec_start
    if rsa_returned!=rsa_plain:
        raise ProtocolError('Actual FPGA RSA private-decrypt plaintext does not match the laptop message')
    recorder.emit('rsa-fpga-plaintext','FPGA returned RSA plaintext: '+show_bytes(rsa_returned),
                  returned_plaintext=rsa_returned.decode('utf-8'),plaintext_match=True,
                  decrypt_s=rsa_dec_s,location='FPGA',operation='private decryption')
    recorder.emit('rsa-pass','RSA: FPGA key generation -> laptop PUBLIC encryption -> FPGA PRIVATE decryption PASS.')
    recorder.emit('customer-flow-pass','CUSTOMER AES / RSA FLOW PASS. LCD glass acceptance remains tied to separate physical evidence.',
                  phase1_passed=8,phase1_total=8,aes_match=True,rsa_private_match=True)
    summary=dict(status='PASS',scope='customer AES/RSA functional flow; not a standalone public MODEXP demo',
                 source_commit=phase1['source_commit'],sof_sha256=phase1['sof_sha256'],core_hz=caps.core_hz,
                 provider='FRESH_UNQUALIFIED' if client.provider==0 else 'TEST_DETERMINISTIC',entropy_qualified=False,
                 phase1=phase1,aes=aes_result,rsa=dict(handle=f'0x{rsa_handle:08x}',modulus_hex=nhex,
                 public_exponent=public.exponent,message=rsa_plain.decode('utf-8'),ciphertext_hex=rsa_cipher.hex(),
                 returned_plaintext=rsa_returned.decode('utf-8'),plaintext_match=True,generation_s=rsa_gen_s,
                 decrypt_s=rsa_dec_s,private_context_exported=False),hardware_statuses=statuses,
                 lcd_relay_configured=status_relay is not None,lcd_glass_verified=False,
                 recording_type='actual customer client events; hardware provenance supplied by lead acceptance record')
    if recorder.output_dir:
        (recorder.output_dir/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-demo-key-export',action='store_true',help='Explicitly authorize disposable DEMO-ONLY AES export to laptop')
    parser.add_argument('--phase1-evidence',type=Path,required=True)
    parser.add_argument('--image-sha256',required=True,help='Exact currently programmed/final accepted SOF hash')
    parser.add_argument('--transport',default='de25_customer_transport:factory')
    parser.add_argument('--expected-provider',choices=('fresh-unqualified','test'),default='fresh-unqualified')
    parser.add_argument('--status-relay',help='Optional module:factory -> callable(actual snapshot), supplied by LCD owner')
    parser.add_argument('--auto',action='store_true',help='Use scripted public messages for genuine hardware recording')
    parser.add_argument('--message',default=DEFAULT_MESSAGE)
    parser.add_argument('--rsa-message')
    parser.add_argument('--record-dir',type=Path)
    args=parser.parse_args()
    if not args.allow_demo_key_export: parser.error('--allow-demo-key-export is mandatory for this DEMO-ONLY flow')
    phase1=load_phase1(args.phase1_evidence,args.image_sha256)
    if args.auto:
        from de25_customer_crypto import utf8_message
        utf8_message(args.message,1024); utf8_message(args.rsa_message if args.rsa_message is not None else args.message,240)
    recorder=PublicRecorder(args.record_dir)
    module,factory=args.transport.rsplit(':',1)
    relay=None; transport=None
    try:
        if args.status_relay:
            rm,rf=args.status_relay.rsplit(':',1); relay=getattr(importlib.import_module(rm),rf)()
        transport=getattr(importlib.import_module(module),factory)()
        client=CustomerClient(transport,0 if args.expected_provider=='fresh-unqualified' else 1,recorder)
        run_customer_flow(client,recorder,phase1,True,args.auto,args.message,args.rsa_message,relay)
    except BaseException as exc:
        recorder.emit('customer-flow-error',f'CUSTOMER FLOW FAILED: {type(exc).__name__}: {exc}')
        if args.record_dir:
            (args.record_dir/'summary.json').write_text(json.dumps(dict(status='FAIL',error=str(exc)),indent=2),encoding='utf-8')
        raise
    finally:
        if transport is not None: transport.close()
        if relay is not None and hasattr(relay,'close'): relay.close()


if __name__=='__main__': main()
