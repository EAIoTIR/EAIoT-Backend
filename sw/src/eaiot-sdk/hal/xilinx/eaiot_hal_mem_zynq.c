
#include "hal/include/eaiot_hal_mem.h"
#include "string.h"

void eaiot_hal_mem_copy(void *dst, const void *src, size_t len)
{
    
    memcpy(dst, src, len);
}
