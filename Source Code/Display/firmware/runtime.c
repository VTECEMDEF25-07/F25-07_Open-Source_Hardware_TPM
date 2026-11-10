/* Freestanding compiler memory helpers. No OS, heap or library dependency. */
#include <stddef.h>
#include <stdint.h>
void *memcpy(void *dest,const void *src,size_t n) {
    unsigned char *d=dest;const unsigned char *s=src;
    for(size_t i=0;i<n;i++)d[i]=s[i];return dest;
}
void *memmove(void *dest,const void *src,size_t n) {
    unsigned char *d=dest;const unsigned char *s=src;
    if((uintptr_t)d<(uintptr_t)s)for(size_t i=0;i<n;i++)d[i]=s[i];
    else for(size_t i=n;i;i--)d[i-1]=s[i-1];return dest;
}
void *memset(void *dest,int value,size_t n) {
    unsigned char *d=dest;for(size_t i=0;i<n;i++)d[i]=(unsigned char)value;return dest;
}
int memcmp(const void *left,const void *right,size_t n) {
    const unsigned char *a=left,*b=right;
    for(size_t i=0;i<n;i++)if(a[i]!=b[i])return a[i]<b[i]?-1:1;return 0;
}
