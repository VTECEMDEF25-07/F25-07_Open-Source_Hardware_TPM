#include "lcd_status.h"
#include <stdio.h>
int main(int argc,char **argv) {
    (void)argv;char line[4096];struct snapshot s;uint8_t frame[1024];
    while(fgets(line,sizeof line,stdin)) {unsigned char ok=(unsigned char)parse_snapshot(line,&s);fwrite(&ok,1,1,stdout);
        if(ok){render_status(frame,&s,argc>1);fwrite(frame,1,sizeof frame,stdout);}}
    return ferror(stdin)||ferror(stdout);
}
