/* eaiot_hal_mem.h */

#ifndef __eaiot_hal_MEM_H__
#define __eaiot_hal_MEM_H__

#include <stdint.h>
#include <stddef.h>

/**
 * eaiot_hal_mem_copy - Copy @len bytes from @src to @dst.
 *
 * The implementation may use memcpy, DMA, or any platform-optimal
 * mechanism. The caller does not need to know which.
 *
 * @dst and @src must not overlap.
 * Blocks until the copy is complete before returning.
 */
void eaiot_hal_mem_copy(void *dst, const void *src, size_t len);

#endif /* eaiot_hal_MEM_H */