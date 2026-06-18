/**
 * protocols/xmodem.c — XMODEM protocol logic
 *
 * Calls eaiot_hal_uart_*() and hal_delay_ms() exclusively.
 * Contains zero register addresses, zero platform #ifdefs.
 *
 * Protocol reference: Ward Christensen (1977), CRC extension by
 * Chuck Forsberg.  Two-EOT handshake per XMODEM specification.
 */

#include "xmodem.h"
#include "hal/include/eaiot_hal_uart.h"
#include "hal/include/eaiot_hal_timer.h"
#include <string.h>

/* ── Protocol byte constants ──────────────────────────────────────────── */
#define SOH           0x01U   /* Start of 128-byte block                   */
#define STX           0x02U   /* Start of 1024-byte block                  */
#define EOT           0x04U   /* End of transmission                       */
#define ACK           0x06U   /* Acknowledge                               */
#define NAK           0x15U   /* Negative acknowledge / classic init       */
#define CAN           0x18U   /* Cancel (two consecutive = abort)          */
#define SUB           0x1AU   /* Padding byte (CTRL-Z)                     */
#define CRC_INIT      'C'     /* Sent by receiver to request CRC mode      */

#define BLOCK_128     128U
#define BLOCK_1K      1024U

/* =========================================================================
 * CRC-16/CCITT  (poly 0x1021, init 0x0000, no final XOR)
 * ========================================================================= */
static uint16_t crc16_byte(uint16_t crc, uint8_t b)
{
    crc ^= (uint16_t)((uint16_t)b << 8);
    for (int i = 0; i < 8; i++)
        crc = (crc & 0x8000U) ? (uint16_t)((crc << 1) ^ 0x1021U)
                               : (uint16_t)(crc << 1);
    return crc;
}

static uint16_t crc16(const uint8_t *data, size_t len)
{
    uint16_t crc = 0U;
    for (size_t i = 0; i < len; i++)
        crc = crc16_byte(crc, data[i]);
    return crc;
}

/* =========================================================================
 * Internal helpers
 * ========================================================================= */

/** Transmit a three-byte CAN-CAN-CAN abort and flush the RX side. */
static void abort_transfer(void)
{
    eaiot_hal_uart_putc(CAN);
    eaiot_hal_uart_putc(CAN);
    eaiot_hal_uart_putc(CAN);
    eaiot_hal_uart_drain_tx();
    eaiot_hal_delay_ms(100U);
    eaiot_hal_uart_flush_rx();
}

/* =========================================================================
 * xmodem_receive
 * ========================================================================= */
xmodem_err_t xmodem_receive(uint8_t          *buf,
                             size_t            buf_len,
                             size_t           *rx_len,
                             xmodem_variant_t  variant)
{
    const int    use_crc    = (variant != XMODEM_VARIANT_CHECKSUM);
    const size_t blk_size   = (variant == XMODEM_VARIANT_1K) ? BLOCK_1K
                                                              : BLOCK_128;
    const uint8_t init_char = use_crc ? (uint8_t)CRC_INIT : (uint8_t)NAK;

    uint8_t  blk_buf[BLOCK_1K];     /* sized for the largest possible block */
    uint8_t  expected_seq = 1U;
    size_t   written      = 0U;
    int      retries      = 0;
    int      can_count    = 0;
    uint8_t  c;

    *rx_len = 0U;

    /* ── Handshake: announce ourselves to the sender ── */
    eaiot_hal_uart_flush_rx();
    eaiot_hal_uart_putc(init_char);

    for (;;) {

        /* Wait for the first byte of the next frame */
        if (!eaiot_hal_uart_getc_timeout(&c, XMODEM_CHAR_TIMEOUT_MS)) {
            if (++retries >= (int)XMODEM_MAX_RETRIES)
                return XMODEM_ERR_TIMEOUT;
            eaiot_hal_uart_putc(init_char);   /* re-announce after each timeout */
            continue;
        }

        /* ── EOT: sender finished ── */
        if (c == EOT) {
            eaiot_hal_uart_putc(NAK);         /* first EOT → NAK (spec requirement) */
            /* Absorb second EOT; tolerate senders that send only one */
            (void)eaiot_hal_uart_getc_timeout(&c, XMODEM_CHAR_TIMEOUT_MS);
            eaiot_hal_uart_putc(ACK);
            *rx_len = written;
            return XMODEM_OK;
        }

        /* ── CAN: check for two consecutive cancels ── */
        if (c == CAN) {
            if (++can_count >= 2)
                return XMODEM_ERR_CANCEL;
            continue;
        }
        can_count = 0;

        /* ── SOH / STX: start of block ── */
        size_t cur_blk;
        if      (c == SOH) { cur_blk = BLOCK_128; }
        else if (c == STX) { cur_blk = BLOCK_1K;  }
        else               { continue; }             /* ignore stray bytes */

        /* ── Sequence bytes ── */
        uint8_t seq, seq_cmp;
        if (!eaiot_hal_uart_getc_timeout(&seq,     XMODEM_CHAR_TIMEOUT_MS) ||
            !eaiot_hal_uart_getc_timeout(&seq_cmp, XMODEM_CHAR_TIMEOUT_MS))
            goto nak_block;

        if ((uint8_t)(seq ^ seq_cmp) != 0xFFU)
            goto nak_block;

        /* ── Data bytes ── */
        for (size_t i = 0; i < cur_blk; i++) {
            if (!eaiot_hal_uart_getc_timeout(&blk_buf[i], XMODEM_CHAR_TIMEOUT_MS))
                goto nak_block;
        }

        /* ── Integrity check ── */
        if (use_crc) {
            uint8_t hi, lo;
            if (!eaiot_hal_uart_getc_timeout(&hi, XMODEM_CHAR_TIMEOUT_MS) ||
                !eaiot_hal_uart_getc_timeout(&lo, XMODEM_CHAR_TIMEOUT_MS))
                goto nak_block;
            uint16_t rx_crc   = ((uint16_t)hi << 8) | lo;
            uint16_t calc_crc = crc16(blk_buf, cur_blk);
            if (rx_crc != calc_crc)
                goto nak_block;
        } else {
            uint8_t rx_sum;
            if (!eaiot_hal_uart_getc_timeout(&rx_sum, XMODEM_CHAR_TIMEOUT_MS))
                goto nak_block;
            uint8_t calc_sum = 0U;
            for (size_t i = 0; i < cur_blk; i++)
                calc_sum += blk_buf[i];
            if (rx_sum != calc_sum)
                goto nak_block;
        }

        /* ── Sequence validation ── */
        if (seq == (uint8_t)(expected_seq - 1U)) {
            /* Duplicate: our previous ACK was lost — re-ACK and discard */
            eaiot_hal_uart_putc(ACK);
            retries = 0;
            continue;
        }
        if (seq != expected_seq) {
            abort_transfer();
            return XMODEM_ERR_SEQUENCE;
        }

        /* ── Store ── */
        if (written + cur_blk > buf_len) {
            abort_transfer();
            return XMODEM_ERR_OVERFLOW;
        }
        memcpy(buf + written, blk_buf, cur_blk);
        written      += cur_blk;
        expected_seq++;
        retries = 0;
        eaiot_hal_uart_putc(ACK);
        continue;

    nak_block:
        eaiot_hal_uart_flush_rx();
        if (++retries >= (int)XMODEM_MAX_RETRIES) {
            abort_transfer();
            return XMODEM_ERR_RETRIES;
        }
        eaiot_hal_uart_putc(NAK);
    }
}

/* =========================================================================
 * xmodem_send
 * ========================================================================= */
xmodem_err_t xmodem_send(const uint8_t    *buf,
                          size_t            len,
                          xmodem_variant_t  variant)
{
    int    use_crc  = (variant != XMODEM_VARIANT_CHECKSUM);
    size_t blk_size = (variant == XMODEM_VARIANT_1K) ? BLOCK_1K : BLOCK_128;

    uint8_t blk_buf[BLOCK_1K];
    uint8_t seq     = 1U;
    size_t  offset  = 0U;
    int     retries = 0;
    uint8_t c;

    /* ── Wait for receiver's opening handshake ── */
    eaiot_hal_uart_flush_rx();
    for (;;) {
        if (!eaiot_hal_uart_getc_timeout(&c, XMODEM_CHAR_TIMEOUT_MS)) {
            if (++retries >= (int)XMODEM_MAX_RETRIES)
                return XMODEM_ERR_TIMEOUT;
            continue;
        }
        if (c == (uint8_t)CRC_INIT) { use_crc = 1; break; }
        if (c == NAK)               { use_crc = 0; break; }
        if (c == CAN)               return XMODEM_ERR_CANCEL;
    }
    retries = 0;

    /* ── Transmit all blocks ── */
    while (offset < len) {
        size_t remaining = len - offset;
        size_t copy_len  = (remaining < blk_size) ? remaining : blk_size;

        memset(blk_buf, SUB, blk_size);
        memcpy(blk_buf, buf + offset, copy_len);

        /* Header */
        eaiot_hal_uart_putc((blk_size == BLOCK_1K) ? (uint8_t)STX : (uint8_t)SOH);
        eaiot_hal_uart_putc(seq);
        eaiot_hal_uart_putc((uint8_t)(0xFFU - seq));

        /* Payload */
        for (size_t i = 0; i < blk_size; i++)
            eaiot_hal_uart_putc(blk_buf[i]);

        /* Integrity trailer */
        if (use_crc) {
            uint16_t crc_val = crc16(blk_buf, blk_size);
            eaiot_hal_uart_putc((uint8_t)(crc_val >> 8));
            eaiot_hal_uart_putc((uint8_t)(crc_val & 0xFFU));
        } else {
            uint8_t sum = 0U;
            for (size_t i = 0; i < blk_size; i++)
                sum += blk_buf[i];
            eaiot_hal_uart_putc(sum);
        }
        eaiot_hal_uart_drain_tx();

        /* Wait for ACK / NAK */
        if (!eaiot_hal_uart_getc_timeout(&c, XMODEM_CHAR_TIMEOUT_MS)) {
            if (++retries >= (int)XMODEM_MAX_RETRIES)
                return XMODEM_ERR_TIMEOUT;
            continue;   /* retransmit same block */
        }

        if (c == ACK) {
            offset  += copy_len;
            seq++;
            retries  = 0;
        } else if (c == NAK) {
            if (++retries >= (int)XMODEM_MAX_RETRIES)
                return XMODEM_ERR_RETRIES;
            /* retransmit */
        } else if (c == CAN) {
            /* require a second CAN before treating as abort */
            if (eaiot_hal_uart_getc_timeout(&c, 1000U) && c == CAN)
                return XMODEM_ERR_CANCEL;
        }
    }

    /* ── End of transmission ── */
    for (int try = 0; try < (int)XMODEM_MAX_RETRIES; try++) {
        eaiot_hal_uart_putc(EOT);
        eaiot_hal_uart_drain_tx();
        if (!eaiot_hal_uart_getc_timeout(&c, XMODEM_CHAR_TIMEOUT_MS))
            continue;
        if (c == ACK) return XMODEM_OK;
        if (c == CAN) return XMODEM_ERR_CANCEL;
        /* NAK → send another EOT */
    }
    return XMODEM_ERR_TIMEOUT;
}

/* =========================================================================
 * xmodem_strerror
 * ========================================================================= */
const char *xmodem_strerror(xmodem_err_t err)
{
    switch (err) {
    case XMODEM_OK:            return "OK";
    case XMODEM_ERR_TIMEOUT:   return "Timeout";
    case XMODEM_ERR_CANCEL:    return "Cancelled by remote (CAN)";
    case XMODEM_ERR_RETRIES:   return "Too many retries";
    case XMODEM_ERR_OVERFLOW:  return "Receive buffer overflow";
    case XMODEM_ERR_SEQUENCE:  return "Block sequence error";
    default:                   return "Unknown error";
    }
}
