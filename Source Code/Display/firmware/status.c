#include "lcd_status.h"
#include "font.h"
static void ws(const char **p) { while (**p==' ' || **p=='\t' || **p=='\r' || **p=='\n') ++*p; }
static int match(const char **p,const char *s) { const char *q=*p; while (*s) if (*q++!=*s++) return 0; *p=q; return 1; }
static int number(const char **p,uint32_t *v) {
    uint32_t n=0; const char *q=*p;
    if (*q<'0'||*q>'9') return 0;
    if (*q=='0' && q[1]>='0' && q[1]<='9') return 0;
    while (*q>='0'&&*q<='9') { uint32_t d=(uint32_t)(*q++-'0'); if(n>429496729U || (n==429496729U && d>5)) return 0; n=n*10+d; }
    *p=q; *v=n; return 1;
}
int parse_snapshot(const char *p,struct snapshot *out) {
    struct snapshot s={0}; unsigned seen=0;
    ws(&p); if(*p++!='{') return 0;
    for(unsigned i=0;i<3;i++) {
        unsigned bit; uint32_t *dest; ws(&p);
        if(match(&p,"\"status_word\"")) {bit=1;dest=&s.status_word;}
        else if(match(&p,"\"operation_id\"")) {bit=2;dest=&s.operation_id;}
        else if(match(&p,"\"sequence\"")) {bit=4;dest=&s.sequence;}
        else return 0;
        if(seen&bit) return 0;
        seen|=bit; ws(&p); if(*p++!=':') return 0; ws(&p);
        if(!number(&p,dest)) return 0;
        ws(&p); if(*p++!=(i==2?'}':',')) return 0;
    }
    ws(&p); uint32_t w=s.status_word;
    if(*p || seen!=7 || (w>>24)!=1 || (w&0xff00) || (!!(w&64)!=((w&15)>=9))) return 0;
    *out=s; return 1;
}
static void text(uint8_t *f,unsigned row,const char *s) {
    unsigned col=0;
    while(*s && col<21) { unsigned c=(unsigned char)*s++; if(c<32||c>90)c='?';
        for(unsigned x=0;x<5;x++) f[row*128+col*6+x]=font[c-32][x];
        col++;
    }
}
static void hexline(uint8_t *f,unsigned row,const char *prefix,uint32_t n,unsigned digits) {
    char b[24]; unsigned j=0; while(*prefix)b[j++]=*prefix++;
    for(unsigned k=digits;k;k--)b[j++]="0123456789ABCDEF"[(n>>((k-1)*4))&15]; b[j]=0; text(f,row,b);
}
void render_status(uint8_t f[1024],const struct snapshot *s,int stale) {
    static const char *states[]={"READY","STARTUP / PHASE I","RNG PREPARE","AES256 KEYGEN","RSA KEYGEN","WAITING FOR INPUT","AES DECRYPT","RSA PRIVATE DECRYPT","DONE","HARDWARE ERROR"};
    static const char *modes[]={"FRESH UNQUALIFIED","TEST ONLY","UNAVAILABLE","INVALID PROVIDER"};
    for(unsigned i=0;i<1024;i++)f[i]=0;
    text(f,0,"DE25 CRYPTO DEMO");
    if(!s || !(s->status_word&128)) {text(f,2,"WAIT HW STATUS");text(f,4,"NO ACTIVE SNAPSHOT");return;}
    uint32_t w=s->status_word,code=w&15,detail=(w>>16)&255;
    const char *state=code<10?states[code]:"UNKNOWN HW STATE";
    if(code==8 && detail==2)state="AES DECRYPT DONE";
    if(code==8 && detail==4)state="RSA DECRYPT DONE";
    text(f,1,modes[(w>>4)&3]);text(f,3,stale?"STATUS STALE":state);
    hexline(f,4,"OP ",s->operation_id,8);hexline(f,5,"DETAIL ",detail,2);hexline(f,6,"SEQ ",s->sequence,8);
    text(f,7,stale?"LAST HW SNAPSHOT":"ACTUAL HW STATUS");
}
