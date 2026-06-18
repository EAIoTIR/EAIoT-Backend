#include "hal/include/eaiot_hal_io.h"
#include "xil_io.h"


uint32_t eaiot_hal_In32(uintptr_t addr) {
    return Xil_In32(addr);
}

void eaiot_hal_Out32(uintptr_t addr, uint32_t data) {
    Xil_Out32(addr, data);
}
