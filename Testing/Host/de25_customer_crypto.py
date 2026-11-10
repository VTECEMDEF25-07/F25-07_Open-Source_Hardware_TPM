"""Host-side encryption only for the explicitly DEMO-ONLY DE25 customer flow.

No RSA private operation, key generation, or private-key import belongs here.
Frozen teaching RSA encoding is deterministic/raw, not OAEP/PKCS encryption.
"""
from dataclasses import dataclass

RSA_WIDTH_BITS=2048
RSA_BYTES=RSA_WIDTH_BITS//8
RSA_MAX_MESSAGE_BYTES=249
AES_MAX_MESSAGE_BYTES=1024


def utf8_message(text: str, maximum: int) -> bytes:
    encoded=text.encode('utf-8')
    if len(encoded)>maximum:
        raise ValueError(f'Message is {len(encoded)} UTF-8 bytes; maximum is {maximum}')
    return encoded


def aes_encrypt_on_laptop(key: bytes, iv: bytes, plaintext: bytes) -> bytes:
    if len(key)!=32 or len(iv)!=16 or len(plaintext)>AES_MAX_MESSAGE_BYTES:
        raise ValueError('AES demo requires a 32-byte disposable key, 16-byte IV and <=1024 bytes')
    from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
    encryptor=Cipher(algorithms.AES(key),modes.CFB(iv)).encryptor()
    return encryptor.update(plaintext)+encryptor.finalize()


def expected_cfb_final_iv(ciphertext: bytes, initial_iv: bytes) -> bytes:
    if len(initial_iv)!=16:
        raise ValueError('IV must be 16 bytes')
    if not ciphertext:
        return initial_iv
    n=len(ciphertext)%16 or 16
    return ciphertext[-n:]+bytes(16-n)


def encode_rsa_demo_message(message: bytes) -> bytes:
    if len(message)>RSA_MAX_MESSAGE_BYTES:
        raise ValueError('Raw RSA teaching frame accepts <=249 message bytes')
    # Exact lead/worker freeze: byte0 zero, DE25, u16 BE length, message, zero tail.
    return b'\0DE25'+len(message).to_bytes(2,'big')+message+bytes(RSA_BYTES-7-len(message))


def validate_rsa_demo_frame(frame: bytes) -> bytes:
    """Reference validator for protocol tests; hardware performs extraction in real flow."""
    if len(frame)!=RSA_BYTES or frame[:5]!=b'\0DE25':
        raise ValueError('Invalid RSA teaching frame marker/width')
    size=int.from_bytes(frame[5:7],'big')
    if size>RSA_MAX_MESSAGE_BYTES or any(frame[7+size:]):
        raise ValueError('Invalid RSA teaching frame length/zero padding')
    return frame[7:7+size]


@dataclass(frozen=True)
class FpgaRsaPublicKey:
    modulus: int
    exponent: int

    @classmethod
    def from_fpga(cls,modulus_be: bytes,exponent_be: bytes):
        if len(modulus_be)!=RSA_BYTES or len(exponent_be)!=4:
            raise ValueError('FPGA RSA public fields must be n[256] and e[4] in big-endian order')
        n=int.from_bytes(modulus_be,'big'); e=int.from_bytes(exponent_be,'big')
        if n.bit_length()!=RSA_WIDTH_BITS or not n&1 or e!=65537:
            raise ValueError('Expected actual full-width RSA2048 modulus and public exponent 65537')
        return cls(n,e)

    def encrypt_on_laptop(self,message: bytes) -> bytes:
        block=encode_rsa_demo_message(message); m=int.from_bytes(block,'big')
        if not 0<=m<self.modulus:
            raise ValueError('Encoded message must be below the FPGA-generated modulus')
        return pow(m,self.exponent,self.modulus).to_bytes(RSA_BYTES,'big')
