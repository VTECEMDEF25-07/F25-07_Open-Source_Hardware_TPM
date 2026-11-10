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
void render_status(uint8_t f[1024],const struct snapshot *s,int stale) {
    static const char *states[]={"READY","RUNNING SELF TESTS","PREPARING RANDOM DATA","GENERATING AES KEY","GENERATING RSA KEY","ENTER MESSAGE ON PC","DECRYPTING AES","DECRYPTING RSA","OPERATION COMPLETE","HARDWARE ERROR"};
    for(unsigned i=0;i<1024;i++)f[i]=0;
    text(f,0,"DE25 CRYPTO DEMO");
    if(!s || !(s->status_word&128)) {text(f,3,"START DEMO ON LAPTOP");return;}
    if(stale) {text(f,3,"DEMO NOT CONNECTED");text(f,5,"START DEMO ON LAPTOP");return;}
    uint32_t w=s->status_word,code=w&15,detail=(w>>16)&255,mode=(w>>4)&3;
    if(mode>=2) {text(f,3,"RNG UNAVAILABLE");return;}
    const char *state=code<10?states[code]:"HARDWARE ERROR";
    if(code==8 && (detail==2 || detail==4)) {
        state="MESSAGE RECEIVED";
        text(f,5,detail==2?"AES DECRYPTED":"RSA DECRYPTED");
    }
    text(f,3,state);
    if(mode==1)text(f,7,"TEST KEYS ONLY");
}
