/**
 * ftp/xmodem_ftp.c — XMODEM → FTP abstraction layer mapping
 *
 * This translation unit is the ONLY place that knows both the FTP
 * interface (ftp_protocol_t) and the XMODEM API (xmodem_send /
 * xmodem_receive).  Everything else is decoupled:
 *
 *   - ftp.c     knows nothing about XMODEM.
 *   - xmodem.c  knows nothing about ftp_protocol_t.
 *   - main.c    knows nothing about xmodem_err_t.
 *
 * To add YMODEM: create ymodem_ftp.c with the same shape as this file.
 * No other files change.
 */

#include "xmodem_ftp.h"
#include "xmodem/xmodem.h"
#include "hal/include/eaiot_hal_uart.h"

/* =========================================================================
 * Context initialiser
 * ========================================================================= */
void xmodem_ftp_ctx_init(xmodem_ftp_ctx_t *ctx, xmodem_variant_t variant)
{
    ctx->variant  = variant;
    ctx->last_err = XMODEM_OK;
}

/* =========================================================================
 * vtable implementations
 * ========================================================================= */

static ftp_err_t xmodem_ftp_open(void *vctx)
{
    (void)vctx;
    /* Flush any stale bytes so the first handshake character is clean. */
    eaiot_hal_uart_flush_rx();
    return FTP_OK;
}

static ftp_err_t xmodem_ftp_close(void *vctx)
{
    (void)vctx;
    /* Drain the TX FIFO so the remote sees the last byte we sent. */
    eaiot_hal_uart_drain_tx();
    return FTP_OK;
}

static ftp_err_t xmodem_ftp_send(void *vctx, const uint8_t *buf, size_t len)
{
    xmodem_ftp_ctx_t *ctx = (xmodem_ftp_ctx_t *)vctx;
    xmodem_err_t err = xmodem_send(buf, len, ctx->variant);
    ctx->last_err = err;
    return (err == XMODEM_OK) ? FTP_OK : FTP_ERR_SEND;
}

static ftp_err_t xmodem_ftp_receive(void *vctx, uint8_t *buf,
                                     size_t buf_len, size_t *rx_len)
{
    xmodem_ftp_ctx_t *ctx = (xmodem_ftp_ctx_t *)vctx;
    xmodem_err_t err = xmodem_receive(buf, buf_len, rx_len, ctx->variant);
    ctx->last_err = err;
    return (err == XMODEM_OK) ? FTP_OK : FTP_ERR_RECEIVE;
}

/* =========================================================================
 * vtable instance  (read-only, safe to share)
 * ========================================================================= */
const ftp_protocol_t xmodem_ftp_protocol = {
    .name    = "XMODEM",
    .open    = xmodem_ftp_open,
    .close   = xmodem_ftp_close,
    .send    = xmodem_ftp_send,
    .receive = xmodem_ftp_receive,
};
