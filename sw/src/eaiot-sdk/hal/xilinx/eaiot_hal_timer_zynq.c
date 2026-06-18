/**
 * hal/include/zynq7020/hal_timer_zynq.c — Zynq-7020 delay implementation
 *
 * Uses a Cortex-A9 CPU-cycle spin loop.  No TTC or GTC peripheral
 * is required, making this safe to use before the interrupt controller
 * or any other peripheral is initialised.
 *
 * Accuracy
 * --------
 *  Cortex-A9 executes the inner loop in approximately 4 cycles per
 *  iteration at O1/O2 optimisation.  At 667 MHz that gives:
 *      1 ms ≈ 667 000 / 4 = 166 750 iterations
 *
 *  Real accuracy depends on cache state and branch prediction.  For
 *  XMODEM timeout purposes (seconds, not microseconds) this is adequate.
 *
 *  To use a hardware timer instead, replace this file with one that
 *  programs a TTC channel or reads the ARM global timer — no other
 *  files need to change.
 */

#include "hal/include/eaiot_hal_timer.h"
#include <stdint.h>

/* Cortex-A9 frequency for the Zynq-7020 (667 MHz typical).
 * Override via -DZYNQ_CPU_FREQ_HZ=<value> in your CFLAGS. */
#ifndef ZYNQ_CPU_FREQ_HZ
#define ZYNQ_CPU_FREQ_HZ    666666667UL
#endif

/* Iterations per millisecond (4 cycles/iter assumed at -O1) */
#define ITERS_PER_MS    ((ZYNQ_CPU_FREQ_HZ) / 1000UL / 4UL)

void eaiot_hal_delay_ms(uint32_t ms)
{
    while (ms--) {
        volatile uint32_t count = (uint32_t)ITERS_PER_MS;
        while (count--)
            ;
    }
}
