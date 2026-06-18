#include "echo_server.h"

#define RX_BUF_SIZE  (1UL * 1024UL * 1024UL)   /* 1 MiB */


void echo_server(ftp_transfer_t* ftp_h) {

    print("\r\n=== Baremetal File Transfer — Zynq-7020 ===\r\n");
    print("Protocol : ");
    print(ftp_protocol_name(ftp_h));
    print("Waiting for transfer...\r\n");

    void* rx_buf = malloc(RX_BUF_SIZE);

    ftp_err_t err;

    /* ── 3. Receive ─────────────────────────────────────────────────────── */
    size_t   rx_len = 0;

    err = ftp_receive(ftp_h, rx_buf, RX_BUF_SIZE, &rx_len);
    if (err == FTP_OK) {
        // print("Received ");
        // printf("%x", (unsigned long)rx_len);
        // print(" bytes OK.\r\n");

        /*
         * Optional: jump to the received image.
         * Ensure D-cache is flushed and I-cache invalidated first.
         *
         *   typedef void (*entry_t)(void);
         *   __asm__ volatile("dsb\n\t isb");
         *   ((entry_t)RX_BUF_ADDR)();
         */
    } else {
        print("Receive failed: ");
        print(ftp_strerror(err));
        print("\r\n");
    }

    err = ftp_send(ftp_h, rx_buf, rx_len);
    if (err == FTP_OK) {
        print("Sent ");
        printf("%x",(unsigned long)rx_len);
        print(" bytes OK.\r\n");

    } else {
        print("Sending failed: ");
        print(ftp_strerror(err));
        print("\r\n");
    }
}
