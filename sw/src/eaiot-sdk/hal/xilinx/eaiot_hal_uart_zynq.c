

#include "hal/include/eaiot_hal_uart.h"
#include "hal/include/eaiot_hal_timer.h"
#include <stddef.h>

#ifndef ZYNQ_UART_BASE
#define ZYNQ_UART_BASE  0xE0001000UL    /* PS UART1; use 0xE0000000 for UART0 */
#endif

/* ── Register offsets (UG585 Table B-34) ─────────────────────────────── */
#define UART_CR         0x00U   /* Control register                */
#define UART_MR         0x04U   /* Mode register                   */
#define UART_BAUDGEN    0x18U   /* Baud rate generator             */
#define UART_RXTO       0x1CU   /* Receiver timeout                */
#define UART_SR         0x2CU   /* Channel status register         */
#define UART_FIFO       0x30U   /* TX / RX FIFO access             */
#define UART_BAUDDIV    0x34U   /* Baud rate divider               */

/* ── Status register bit masks ────────────────────────────────────────── */
#define SR_RXEMPTY  (1U << 1)   /* RX FIFO empty                   */
#define SR_TXFULL   (1U << 4)   /* TX FIFO full                    */
#define SR_TXEMPTY  (1U << 3)   /* TX FIFO empty (and shift reg)   */

/* ── Register accessor ────────────────────────────────────────────────── */
static inline volatile uint32_t *reg(uint32_t off)
{
    return (volatile uint32_t *)(ZYNQ_UART_BASE + off);
}


void hal_uart_zynq_init(void)
{
    /* Reset TX and RX paths */
    *reg(UART_CR) = (1U << 1) | (1U << 0);     /* TXRES | RXRES */

    /* 8-N-1, normal channel mode */
    *reg(UART_MR) = 0x00000020U;

    /* Baud rate: 115 200 @ 50 MHz ref */
    *reg(UART_BAUDGEN) = 62U;
    *reg(UART_BAUDDIV) = 6U;

    /* Disable RX timeout (we implement our own in software) */
    *reg(UART_RXTO) = 0U;

    /* Enable TX and RX */
    *reg(UART_CR) = (1U << 4) | (1U << 2);     /* TXEN | RXEN */
}


void eaiot_hal_uart_putc(uint8_t c)
{
    while (*reg(UART_SR) & SR_TXFULL)
        ;
    *reg(UART_FIFO) = c;
}

int eaiot_hal_uart_getc_timeout(uint8_t *c, uint32_t timeout_ms)
{
    uint32_t slices = (timeout_ms == 0U) ? 1U : timeout_ms;
    while (slices--) {
        if (!(*reg(UART_SR) & SR_RXEMPTY)) {
            *c = (uint8_t)(*reg(UART_FIFO) & 0xFFU);
            return 1;
        }
        eaiot_hal_delay_ms(1U);
    }
    return 0;
}

void eaiot_hal_uart_flush_rx(void)
{
    while (!(*reg(UART_SR) & SR_RXEMPTY))
        (void)*reg(UART_FIFO);
}

void eaiot_hal_uart_drain_tx(void)
{
    while (!(*reg(UART_SR) & SR_TXEMPTY))
        ;
}
