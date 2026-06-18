/**
 * ftp/xmodem_ftp.h — XMODEM binding for the FTP abstraction layer
 *
 * Provides a ready-made ftp_protocol_t and a context initialiser so that
 * callers can use XMODEM through the generic ftp_transfer_t interface.
 *
 * Usage
 * -----
 *   #include "ftp/ftp.h"
 *   #include "ftp/xmodem_ftp.h"
 *
 *   xmodem_ftp_ctx_t  ctx;
 *   ftp_transfer_t    xfer = {0};
 *
 *   xmodem_ftp_ctx_init(&ctx, XMODEM_VARIANT_1K);
 *   ftp_open(&xfer, &xmodem_ftp_protocol, &ctx);
 *
 *   ftp_receive(&xfer, buf, sizeof(buf), &n);
 *   // or
 *   ftp_send(&xfer, buf, n);
 *
 *   ftp_close(&xfer);
 */

#ifndef FTP_XMODEM_FTP_H
#define FTP_XMODEM_FTP_H

#include "ftp/ftp.h"
#include "xmodem/xmodem.h"

/* ── Protocol context ─────────────────────────────────────────────────── */

/**
 * xmodem_ftp_ctx_t - Per-session configuration for the XMODEM binding.
 *
 * Stack-allocate one of these and pass its address to ftp_open() as @ctx.
 * Do NOT share a context between concurrent transfers.
 */
typedef struct {
    xmodem_variant_t variant;   /**< XMODEM variant selected for this session */
    xmodem_err_t     last_err;  /**< Last raw XMODEM error (diagnostic use)   */
} xmodem_ftp_ctx_t;

/**
 * xmodem_ftp_ctx_init - Initialise a context before passing it to ftp_open().
 *
 * @param ctx      Context to initialise.  Must not be NULL.
 * @param variant  XMODEM variant (CHECKSUM, CRC, or 1K).
 */
void xmodem_ftp_ctx_init(xmodem_ftp_ctx_t *ctx, xmodem_variant_t variant);

/* ── Protocol vtable instance ─────────────────────────────────────────── */

/**
 * xmodem_ftp_protocol - Pass this to ftp_open() to use XMODEM.
 *
 * This is a statically allocated, read-only vtable; it is safe to share
 * between multiple (sequential) transfers.
 */
extern const ftp_protocol_t xmodem_ftp_protocol;

#endif /* FTP_XMODEM_FTP_H */
