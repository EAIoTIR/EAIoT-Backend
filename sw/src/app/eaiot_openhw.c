#include "eaiot_openhw.h"
#include "stdint.h"
#include "stdlib.h"
#include "models/model_wrapper.h"

#define RX_BUF_SIZE  (1UL * 1024UL * 1024UL)   /* 1 MiB */

void eaiot_openhw(ftp_transfer_t* xfer) {

    void* rx_buf = malloc(RX_BUF_SIZE);

    ftp_err_t err;


    size_t   rx_len = 0;

    err = ftp_receive(xfer, rx_buf, RX_BUF_SIZE, &rx_len);
    if (err == FTP_OK) {

    } else {
        print("Receive failed: ");
        print(ftp_strerror(err));
        print("\r\n");
    }

    void* output;
    size_t output_len;

    run_onnx2c(rx_buf , &output , &output_len);

    err = ftp_send(xfer, output, output_len);
    if (err == FTP_OK) {
        print("Sent ");
        printf("%x",(unsigned long)output_len);
        print(" bytes OK.\r\n");

    } else {
        print("Sending failed: ");
        print(ftp_strerror(err));
        print("\r\n");
    }


    return;
}
