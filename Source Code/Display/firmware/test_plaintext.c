#include "lcd_status.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void) {
 struct plaintext_frame t;struct snapshot s={0x01020088,7,12};
 const char *good="{\"plaintext_b64\":\"SGVsbG8sIExlbm92byE=\",\"algorithm\":2,\"operation_id\":7,\"sequence\":12}";
 assert(parse_plaintext(good,&t));assert(t.length==14&&!memcmp(t.bytes,"Hello, Lenovo!",14));
 assert(plaintext_matches(&t,&s));s.operation_id++;assert(!plaintext_matches(&t,&s));s.operation_id--;
 s.sequence++;assert(!plaintext_matches(&t,&s));s.sequence--;s.status_word=0x01040088;assert(!plaintext_matches(&t,&s));s.status_word=0x01020088;
 const char *bad[]={"{}","{\"plaintext_b64\":\"A===\",\"algorithm\":2,\"operation_id\":7,\"sequence\":12}",
 "{\"plaintext_b64\":\"AB==\",\"algorithm\":2,\"operation_id\":7,\"sequence\":12}",
 "{\"plaintext_b64\":\"AAA=\",\"algorithm\":3,\"operation_id\":7,\"sequence\":12}",
 "{\"plaintext_b64\":\"AAAA\",\"algorithm\":2,\"operation_id\":7,\"operation_id\":12}",
 "{\"plaintext_b64\":\"AA\",\"algorithm\":2,\"operation_id\":7,\"sequence\":12}",
 "{\"plaintext_b64\":\"AAAA\",\"algorithm\":2,\"operation_id\":-1,\"sequence\":12}"};
 for(unsigned i=0;i<sizeof bad/sizeof *bad;i++)assert(!parse_plaintext(bad[i],&t));
 char encoded[169],line[256];for(unsigned i=0;i<42;i++)memcpy(encoded+4*i,"QUFB",4);encoded[168]=0;
 snprintf(line,sizeof line,"{\"plaintext_b64\":\"%s\",\"algorithm\":4,\"operation_id\":4294967295,\"sequence\":4294967295}",encoded);
 assert(parse_plaintext(line,&t)&&t.length==126);for(unsigned i=0;i<126;i++)assert(t.bytes[i]=='A');
 struct {uint8_t before[16],frame[1024],after[16];} guarded;memset(&guarded,0xa5,sizeof guarded);
 render_plaintext(guarded.frame,&t);
 for(unsigned i=0;i<16;i++)assert(guarded.before[i]==0xa5&&guarded.after[i]==0xa5);
 assert(guarded.frame[2*128]!=0&&guarded.frame[7*128]!=0);
 assert(parse_plaintext(good,&t));render_plaintext(guarded.frame,&t);
 assert(guarded.frame[2*128+6]!=0); /* lowercase e exists, not unsupported '?' */
 assert(parse_plaintext("{\"plaintext_b64\":\"\",\"algorithm\":2,\"operation_id\":0,\"sequence\":0}",&t)&&t.length==0);
 puts("PASS plaintext: actual-DONE identity binding, strict base64, 126-byte clipping, lowercase and framebuffer canaries");
 return 0;
}
