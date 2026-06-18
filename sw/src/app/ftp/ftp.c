/**
 * ftp/ftp.c — File Transfer Protocol Abstraction Layer implementation
 *
 * Thin dispatch layer: validates state, calls through the vtable, and maps
 * protocol-specific errors to ftp_err_t values.  No protocol logic here.
 */

#include "ftp.h"
#include <stddef.h>

/* =========================================================================
 * ftp_open
 * ========================================================================= */
ftp_err_t ftp_open(ftp_transfer_t       *transfer,
                   const ftp_protocol_t *protocol,
                   void                 *ctx)
{
    if (!protocol ||
        !protocol->open    ||
        !protocol->close   ||
        !protocol->send    ||
        !protocol->receive)
        return FTP_ERR_NULL_PROTOCOL;

    if (transfer->is_open)
        return FTP_ERR_ALREADY_OPEN;

    transfer->protocol = protocol;
    transfer->ctx      = ctx;
    transfer->is_open  = 0;    /* set to 1 only after open() succeeds */

    ftp_err_t err = protocol->open(ctx);
    if (err == FTP_OK)
        transfer->is_open = 1;

    return err;
}

/* =========================================================================
 * ftp_close
 * ========================================================================= */
ftp_err_t ftp_close(ftp_transfer_t *transfer)
{
    if (!transfer->is_open)
        return FTP_ERR_NOT_OPEN;

    ftp_err_t err    = transfer->protocol->close(transfer->ctx);
    transfer->is_open = 0;
    transfer->protocol = NULL;
    transfer->ctx      = NULL;
    return err;
}

/* =========================================================================
 * ftp_send
 * ========================================================================= */
ftp_err_t ftp_send(ftp_transfer_t *transfer, const uint8_t *buf, size_t len)
{
    if (!transfer->is_open)
        return FTP_ERR_NOT_OPEN;
    if (!buf || len == 0U)
        return FTP_ERR_INVALID_ARG;

    ftp_err_t err = transfer->protocol->send(transfer->ctx, buf, len);
    return (err == FTP_OK) ? FTP_OK : FTP_ERR_SEND;
}

/* =========================================================================
 * ftp_receive
 * ========================================================================= */
ftp_err_t ftp_receive(ftp_transfer_t *transfer,
                      uint8_t        *buf,
                      size_t          buf_len,
                      size_t         *rx_len)
{
    if (rx_len)
        *rx_len = 0U;

    if (!transfer->is_open)
        return FTP_ERR_NOT_OPEN;
    if (!buf || buf_len == 0U || !rx_len)
        return FTP_ERR_INVALID_ARG;

    ftp_err_t err = transfer->protocol->receive(transfer->ctx,
                                                 buf, buf_len, rx_len);
    return (err == FTP_OK) ? FTP_OK : FTP_ERR_RECEIVE;
}

/* =========================================================================
 * ftp_protocol_name
 * ========================================================================= */
const char *ftp_protocol_name(const ftp_transfer_t *transfer)
{
    if (!transfer || !transfer->is_open || !transfer->protocol)
        return "(none)";
    return transfer->protocol->name;
}

/* =========================================================================
 * ftp_strerror
 * ========================================================================= */
const char *ftp_strerror(ftp_err_t err)
{
    switch (err) {
    case FTP_OK:                return "OK";
    case FTP_ERR_NOT_OPEN:      return "Transfer not open";
    case FTP_ERR_ALREADY_OPEN:  return "Transfer already open";
    case FTP_ERR_SEND:          return "Send failed";
    case FTP_ERR_RECEIVE:       return "Receive failed";
    case FTP_ERR_NULL_PROTOCOL: return "Null or incomplete protocol vtable";
    case FTP_ERR_INVALID_ARG:   return "Invalid argument (null buf or zero len)";
    default:                    return "Unknown FTP error";
    }
}
