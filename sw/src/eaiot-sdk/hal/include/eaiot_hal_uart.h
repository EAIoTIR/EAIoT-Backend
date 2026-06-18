

#ifndef __eaiot_hal_UART_H__
#define __eaiot_hal_UART_H__

#include <stdint.h>

void eaiot_hal_uart_putc(uint8_t c);

int eaiot_hal_uart_getc_timeout(uint8_t *c, uint32_t timeout_ms);

void eaiot_hal_uart_flush_rx(void);

void eaiot_hal_uart_drain_tx(void);

#endif 
