#include "application.h"
#include "ftp/ftp.h"
#include "ftp/adapter/xmodem/xmodem_ftp.h" 

#include "eaiot_openhw.h"

ftp_transfer_t xfer = {0};



int init_application() {

    xmodem_ftp_ctx_t ctx;                              
    xmodem_ftp_ctx_init(&ctx, XMODEM_VARIANT_1K);      


    ftp_err_t err = ftp_open(&xfer, &xmodem_ftp_protocol, &ctx);
    if (err != FTP_OK) {
        print("ftp_open failed: ");
        print(ftp_strerror(err));
        print("\r\n");
        return -1;
    }

    return 0;
}

int cleanup_application() {

    ftp_close(&xfer);

    return 0;
}

int run_application() {

    eaiot_openhw(&xfer);

}