/* Control-only RSA-2048 sequencing. Secret arithmetic stays in the accelerator.
 * Firmware cannot read candidate limbs, witnesses, primes, or private exponent.
 * Service implementation and FIPS mapping are verified separately. */
#include <stdint.h>
#define MMIO ((volatile uint32_t *)0x40000000u)
enum { W=0, WM1=32, M=64, B=96, Z=128, P=160, Q=192, N=224,
       ONE=288, TWO=320, TMP_Z=352, MONT_WORK=512 };
enum { COPY=0x01, MOD_SETUP=0x11, MODEXP=0x13, DRAW=0x30,
       PREPARE_PRIME=0x31, WITNESS_CHECK=0x32, MR_CHECK=0x33, PAIR_CHECK=0x34 };
enum { SUCCESS=0, RNG_FAILURE=2, SEARCH_EXHAUSTED=3, ARITH_FAILURE=4 };

static uint32_t command(uint32_t opcode, uint32_t a, uint32_t b, uint32_t c, uint32_t d)
{
    uint32_t status;
    MMIO[2]=a; MMIO[3]=b; MMIO[4]=c; MMIO[5]=d;
    MMIO[0]=opcode;
    do { status=MMIO[1]; } while ((status & 2u)==0u);
    MMIO[6]=1u;
    return (status >> 8) & 255u;
}

static uint32_t prime(uint32_t q_mode)
{
    uint32_t rejected=0, round, status;
    const uint32_t limit=q_mode ? 20480u : 10240u;
    for (;;) {
        if (command(DRAW,W,32,1,0)!=0) return RNG_FAILURE;
        status=command(PREPARE_PRIME,W,WM1,M,q_mode);
        /* Range and pair-separation redraws do not consume the retry budget. */
        if (status==0x10u || status==0x11u) continue;
        if (status==0x12u) goto composite;
        if (status!=0) return ARITH_FAILURE;
        if (command(MOD_SETUP,W,MONT_WORK,32,0)!=0) return ARITH_FAILURE;
        for (round=0;round<5;round++) {
            do {
                if (command(DRAW,B,32,0,0)!=0) return RNG_FAILURE;
                status=command(WITNESS_CHECK,B,0,0,0);
            } while (status==0x10u);
            if (status!=0) return ARITH_FAILURE;
            if (command(MODEXP,Z,B,M,32)!=0) return ARITH_FAILURE;
            status=command(MR_CHECK,1,0,0,0);
            while (status==0x10u) {
                /* Nonoverlapping destination avoids assumptions about aliasing. */
                if (command(MODEXP,TMP_Z,Z,TWO,1)!=0) return ARITH_FAILURE;
                if (command(COPY,Z,TMP_Z,0,32)!=0) return ARITH_FAILURE;
                status=command(MR_CHECK,0,0,0,0);
            }
            if (status==0x11u) goto composite;
            if (status!=0) return ARITH_FAILURE;
        }
        if (command(COPY,q_mode ? Q : P,W,0,32)!=0) return ARITH_FAILURE;
        return SUCCESS;
composite:
        rejected++;
        if (rejected>=limit) return SEARCH_EXHAUSTED;
    }
}

int main(void)
{
    uint32_t status;
    for (;;) {
        status=prime(0); if (status!=0) break;
        status=prime(1); if (status!=0) break;
        status=command(PAIR_CHECK,0,0,0,0);
        if (status==0x10u) continue; /* A short d restarts both prime searches. */
        if (status!=0) status=ARITH_FAILURE;
        break;
    }
    MMIO[7]=0xa5000000u | status;
    /* Parent stops CPU, clears local CPU/RAM, then exposes held completion. */
    for (;;) { __asm__ volatile ("nop"); }
}
