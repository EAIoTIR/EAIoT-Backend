#ifndef __EAIOT_OPENHW_H__
#define __EAIOT_OPENHW_H__

#include "ftp/ftp.h"
#include "llrt/layer/QGemm.h"
#include "llrt/layer/QConv1d.h"
#include "llrt/layer/QConv2d.h"


void eaiot_openhw(ftp_transfer_t* xfer);

#endif