/**
 * ftp/ftp.h — File Transfer Protocol Abstraction Layer
 *
 * Defines a single vtable-style struct (ftp_protocol_t) that every
 * concrete file transfer protocol must implement.  Application code
 * works exclusively with this type and never calls protocol functions
 * directly, making it trivially easy to swap or add protocols at runtime.
 *
 * Architecture
 * ============
 *
 *   Application
 *       │  uses ftp_transfer_t  (open / send / receive / close)
 *       ▼
 *   ftp.h  ──  ftp_protocol_t  (vtable: fn pointers)
 *       │
 *       ├── xmodem_ftp.c  maps XMODEM → ftp_protocol_t
 *       ├── ymodem_ftp.c  (future)
 *       └── zmodem_ftp.c  (future)
 *
 * Adding a new protocol
 * =====================
 *  1. Implement the four functions below for your protocol.
 *  2. Create a ftp_protocol_t initialiser (see xmodem_ftp.c for the pattern).
 *  3. Pass the initialiser to ftp_open() — done.
 *     No changes required in ftp.h, no changes in application code.
 *
 * Error handling
 * ==============
 *  All functions return ftp_err_t.  FTP_OK is 0; all errors are negative.
 *  Use ftp_strerror() for human-readable descriptions.
 */

#ifndef FTP_H
#define FTP_H

#include <stdint.h>
#include <stddef.h>

/* =========================================================================
 * Error codes
 * ========================================================================= */
typedef enum {
    FTP_OK                  =  0,
    FTP_ERR_NOT_OPEN        = -1,   /**< ftp_send/receive called before open */
    FTP_ERR_ALREADY_OPEN    = -2,   /**< ftp_open called twice               */
    FTP_ERR_SEND            = -3,   /**< Underlying send failed              */
    FTP_ERR_RECEIVE         = -4,   /**< Underlying receive failed           */
    FTP_ERR_NULL_PROTOCOL   = -5,   /**< Null protocol or missing fn pointer */
    FTP_ERR_INVALID_ARG     = -6,   /**< Null buffer or zero length          */
} ftp_err_t;

/* =========================================================================
 * Protocol vtable
 *
 * Each concrete protocol fills in a static instance of this struct.
 * Function pointers must not be NULL; set them to a stub that returns
 * an error if a direction is genuinely unsupported.
 * ========================================================================= */
typedef struct ftp_protocol {
    /** Short human-readable name, e.g. "XMODEM-1K".  Never NULL. */
    const char *name;

    /**
     * open - Prepare the channel for transfer.
     *
     * Called once before any send/receive.  Implementations typically
     * flush the RX buffer and configure any protocol-specific state that
     * lives in @ctx.
     *
     * @param ctx   Protocol-private context pointer (may be NULL if the
     *              protocol needs no persistent state).
     * @return      FTP_OK or a negative error code.
     */
    ftp_err_t (*open)(void *ctx);

    /**
     * close - Release the channel after transfer.
     *
     * Called once when the caller is done.  Implementations should
     * flush buffers and leave the hardware in a quiescent state.
     *
     * @param ctx   Same pointer passed to open().
     * @return      FTP_OK or a negative error code.
     */
    ftp_err_t (*close)(void *ctx);

    /**
     * send - Transmit @len bytes from @buf to the remote peer.
     *
     * @param ctx   Protocol-private context.
     * @param buf   Data to send.  Must not be NULL.
     * @param len   Number of bytes.  Must be > 0.
     * @return      FTP_OK or a negative error code.
     */
    ftp_err_t (*send)(void *ctx, const uint8_t *buf, size_t len);

    /**
     * receive - Receive data from the remote peer into @buf.
     *
     * @param ctx       Protocol-private context.
     * @param buf       Destination buffer.  Must not be NULL.
     * @param buf_len   Capacity of @buf in bytes.
     * @param rx_len    [out] Bytes actually written into @buf.
     * @return          FTP_OK or a negative error code.
     */
    ftp_err_t (*receive)(void *ctx, uint8_t *buf, size_t buf_len,
                         size_t *rx_len);
} ftp_protocol_t;

/* =========================================================================
 * Transfer handle
 *
 * Opaque to the caller; created by ftp_open(), destroyed by ftp_close().
 * Declare on the stack — no heap allocation.
 * ========================================================================= */
typedef struct {
    const ftp_protocol_t *protocol;  /**< Vtable pointer (set by ftp_open) */
    void                 *ctx;       /**< Forwarded to every vtable call    */
    int                   is_open;   /**< Guard against double-open/close   */
} ftp_transfer_t;

/* =========================================================================
 * Public API
 * ========================================================================= */

/**
 * ftp_open - Bind a protocol to a transfer handle and open the channel.
 *
 * @param transfer   Uninitialised handle; filled in by this call.
 * @param protocol   Vtable describing the chosen protocol.  Must not be NULL.
 * @param ctx        Protocol-private context forwarded to every vtable call.
 *                   Pass NULL if the protocol needs no context.
 * @return           FTP_OK or FTP_ERR_NULL_PROTOCOL / FTP_ERR_ALREADY_OPEN.
 */
ftp_err_t ftp_open(ftp_transfer_t       *transfer,
                   const ftp_protocol_t *protocol,
                   void                 *ctx);

/**
 * ftp_close - Flush, tear down, and reset @transfer.
 *
 * After this call @transfer may be reused with ftp_open().
 *
 * @return  FTP_OK, FTP_ERR_NOT_OPEN, or whatever the protocol's close()
 *          returns.
 */
ftp_err_t ftp_close(ftp_transfer_t *transfer);

/**
 * ftp_send - Send @len bytes from @buf using the bound protocol.
 *
 * @return  FTP_OK, FTP_ERR_NOT_OPEN, FTP_ERR_INVALID_ARG, or
 *          FTP_ERR_SEND wrapping the underlying protocol error.
 */
ftp_err_t ftp_send(ftp_transfer_t *transfer, const uint8_t *buf, size_t len);

/**
 * ftp_receive - Receive data into @buf using the bound protocol.
 *
 * @param rx_len  [out] Bytes written; set to 0 on error.
 * @return        FTP_OK, FTP_ERR_NOT_OPEN, FTP_ERR_INVALID_ARG, or
 *                FTP_ERR_RECEIVE wrapping the underlying protocol error.
 */
ftp_err_t ftp_receive(ftp_transfer_t *transfer,
                      uint8_t        *buf,
                      size_t          buf_len,
                      size_t         *rx_len);

/**
 * ftp_protocol_name - Return the name of the currently bound protocol,
 *                     or "(none)" if the handle is not open.
 */
const char *ftp_protocol_name(const ftp_transfer_t *transfer);

/** Human-readable description of an ftp_err_t. */
const char *ftp_strerror(ftp_err_t err);

#endif /* FTP_H */
