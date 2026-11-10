/* Offline header ABI check, no devices opened. Linux generic ABI also arm64. */
#include <stdio.h>
#include <linux/gpio.h>
#include <linux/spi/spidev.h>
int main(void) {
    _Static_assert(sizeof(struct gpiohandle_request)==364,"gpio request size");
    _Static_assert(GPIO_GET_LINEHANDLE_IOCTL==0xc16cb403UL,"gpio request ioctl");
    _Static_assert(GPIOHANDLE_SET_LINE_VALUES_IOCTL==0xc040b409UL,"gpio values ioctl");
    _Static_assert(SPI_IOC_WR_MODE==0x40016b01UL,"mode ioctl");
    _Static_assert(SPI_IOC_WR_LSB_FIRST==0x40016b02UL,"bit order ioctl");
    _Static_assert(SPI_IOC_WR_BITS_PER_WORD==0x40016b03UL,"word ioctl");
    _Static_assert(SPI_IOC_WR_MAX_SPEED_HZ==0x40046b04UL,"speed ioctl");
    puts("PASS LCD_LINUX_ABI 7 header assertions; no device access");
    return 0;
}
