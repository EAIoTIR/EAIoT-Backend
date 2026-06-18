
#ifndef PROTOCOLS_XMODEM_H
#define PROTOCOLS_XMODEM_H

#include <stdint.h>
#include <stddef.h>


#ifndef XMODEM_CHAR_TIMEOUT_MS
#define XMODEM_CHAR_TIMEOUT_MS  3000U
#endif

#ifndef XMODEM_MAX_RETRIES
#define XMODEM_MAX_RETRIES      10U
#endif

/* ── Error codes ──────────────────────────────────────────────────────── */
typedef enum {
    XMODEM_OK            =  0,  /**< Transfer completed successfully        */
    XMODEM_ERR_TIMEOUT   = -1,  /**< Remote stopped responding             */
    XMODEM_ERR_CANCEL    = -2,  /**< Remote sent CAN-CAN abort             */
    XMODEM_ERR_RETRIES   = -3,  /**< Too many consecutive errors           */
    XMODEM_ERR_OVERFLOW  = -4,  /**< Receive buffer too small              */
    XMODEM_ERR_SEQUENCE  = -5,  /**< Unexpected block sequence number      */
} xmodem_err_t;

/* ── Protocol variant ─────────────────────────────────────────────────── */
typedef enum {
    XMODEM_VARIANT_CHECKSUM = 0, /**< Classic (128 B, 8-bit checksum)      */
    XMODEM_VARIANT_CRC      = 1, /**< CRC variant (128 B, CRC-16/CCITT)    */
    XMODEM_VARIANT_1K       = 2, /**< 1K variant  (1024 B, CRC-16/CCITT)  */
} xmodem_variant_t;

/* ── Public API ───────────────────────────────────────────────────────── */

/**
 * xmodem_receive - Receive a file into @buf.
 *
 * @param buf       Destination buffer.
 * @param buf_len   Capacity of @buf in bytes.
 * @param rx_len    [out] Bytes written.  May include up to (block_size-1)
 *                  bytes of 0x1A padding on the final block.
 * @param variant   Protocol variant to negotiate.
 * @return          XMODEM_OK or a negative error code.
 */
xmodem_err_t xmodem_receive(uint8_t       *buf,
                             size_t         buf_len,
                             size_t        *rx_len,
                             xmodem_variant_t variant);

/**
 * xmodem_send - Send @len bytes from @buf.
 *
 * The final block is padded with 0x1A (CTRL-Z) if @len is not a multiple
 * of the block size.  variant is advisory: if the receiver initiates with
 * NAK instead of 'C', checksum mode is used regardless.
 *
 * @param buf       Source data.
 * @param len       Number of bytes to send.
 * @param variant   Preferred protocol variant.
 * @return          XMODEM_OK or a negative error code.
 */
xmodem_err_t xmodem_send(const uint8_t   *buf,
                          size_t           len,
                          xmodem_variant_t variant);

/** Human-readable description of an error code. */
const char *xmodem_strerror(xmodem_err_t err);

#endif /* PROTOCOLS_XMODEM_H */
