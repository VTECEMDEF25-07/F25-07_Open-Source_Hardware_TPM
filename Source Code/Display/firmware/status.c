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
static int b64(unsigned c) {
    if(c>='A'&&c<='Z')return (int)c-'A';
    if(c>='a'&&c<='z')return (int)c-'a'+26;
    if(c>='0'&&c<='9')return (int)c-'0'+52;
    if(c=='+')return 62;if(c=='/')return 63;return -1;
}
int parse_plaintext(const char *p,struct plaintext_frame *out) {
    struct plaintext_frame t={0};unsigned seen=0;ws(&p);if(*p++!='{')return 0;
    for(unsigned field=0;field<4;field++) {
        unsigned bit;uint32_t *dest=0;ws(&p);
        if(match(&p,"\"plaintext_b64\""))bit=1;
        else if(match(&p,"\"algorithm\"")){bit=2;dest=&t.algorithm;}
        else if(match(&p,"\"operation_id\"")){bit=4;dest=&t.operation_id;}
        else if(match(&p,"\"sequence\"")){bit=8;dest=&t.sequence;}
        else return 0;
        if(seen&bit)return 0;seen|=bit;ws(&p);if(*p++!=':')return 0;ws(&p);
        if(bit!=1){if(!number(&p,dest))return 0;}
        else {
            if(*p++!='"')return 0;unsigned n=0;int padded=0;
            while(*p!='"') {
                if(padded || !p[0] || !p[1] || !p[2] || !p[3])return 0;
                int a=b64((unsigned char)p[0]),b=b64((unsigned char)p[1]);
                int c=p[2]=='='?0:b64((unsigned char)p[2]),d=p[3]=='='?0:b64((unsigned char)p[3]);
                if(a<0||b<0||c<0||d<0)return 0;
                unsigned count=p[2]=='='?1:p[3]=='='?2:3;
                if((count==1&&(p[3]!='='||(b&15))) || (count==2&&(c&3)) || n+count>126)return 0;
                t.bytes[n++]=(uint8_t)((a<<2)|(b>>4));
                if(count>1)t.bytes[n++]=(uint8_t)((b<<4)|(c>>2));
                if(count>2)t.bytes[n++]=(uint8_t)((c<<6)|d);
                padded=count<3;p+=4;
            }
            p++;t.length=n;
        }
        ws(&p);if(*p++!=(field==3?'}':','))return 0;
    }
    ws(&p);if(*p||seen!=15||(t.algorithm!=2&&t.algorithm!=4))return 0;
    *out=t;return 1;
}
int plaintext_matches(const struct plaintext_frame *t,const struct snapshot *s) {
    return (s->status_word&128) && (s->status_word&15)==8 && ((s->status_word>>16)&255)==t->algorithm
        && s->operation_id==t->operation_id && s->sequence==t->sequence;
}
static void glyph(uint8_t *f,unsigned row,unsigned col,unsigned c) {
    if(c<32||c>126)c='?';
    for(unsigned x=0;x<5;x++)f[row*128+col*6+x]=font[c-32][x];
}
static void text(uint8_t *f,unsigned row,const char *s) {
    unsigned col=0;
    while(*s && col<21) { unsigned c=(unsigned char)*s++;
        glyph(f,row,col,c);
        col++;
    }
}
void render_plaintext(uint8_t f[1024],const struct plaintext_frame *t) {
    for(unsigned i=0;i<1024;i++)f[i]=0;
    text(f,0,t->algorithm==2?"AES DECRYPTED":"RSA DECRYPTED");
    unsigned row=2,col=0;
    for(unsigned i=0;i<t->length && row<8;i++) {
        unsigned c=t->bytes[i];
        if(c=='\n'){row++;col=0;continue;}
        if(c=='\r')continue;
        glyph(f,row,col,c);if(++col==21){col=0;row++;}
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
