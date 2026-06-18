/**
 * hal/include/hal_timer.h — Timer / Delay Hardware Abstraction Layer
 *
 * Provides a single blocking millisecond delay primitive.
 * Protocol code uses this instead of raw spin loops so that the
 * delay implementation can be swapped (spin loop, TTC timer,
 * RTOS vTaskDelay, etc.) without touching protocol logic.
 *
 * Porting
 * -------
 *  Implement hal_delay_ms() in hal/include/<target>/hal_timer_<target>.c.
 */

#ifndef __eaiot_hal_TIMER_H__
#define __eaiot_hal_TIMER_H__

#include <stdint.h>

/**
 * hal_delay_ms - Spin (or sleep) for at least @ms milliseconds.
 *
 * Accuracy requirements: ±20 % is sufficient for XMODEM timeouts.
 * The implementation MUST NOT return early.
 */
void eaiot_hal_delay_ms(uint32_t ms);

#endif /* HAL_TIMER_H */
