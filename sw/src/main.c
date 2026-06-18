#include "xilinx/platform.h"
#include "application.h"



int main(void)
{

    init_platform();
    init_application();

    run_application();

    cleanup_application();
    cleanup_platform();
    
    return 0;
}
