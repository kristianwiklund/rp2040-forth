/*
 * sd_hw_config.c — carlk3 FatFs_SPI hardware configuration
 *
 * Board: Olimex RP2040-PICO-PC
 *   SPI0: MISO=GP4  CLK=GP6  MOSI=GP7  CS=GP21
 */

#include <string.h>
#include "hw_config.h"   /* declares sd_card_t, spi_t, get_by_num functions */
#include "diskio.h"      /* STA_NOINIT */

/* Forward-declare the DMA ISR defined below */
void spi0_dma_isr(void);

static spi_t spis[] = {
    {
        .hw_inst   = spi0,
        .miso_gpio = 4,
        .mosi_gpio = 7,
        .sck_gpio  = 6,
        .baud_rate = 12500000,
        .dma_isr   = spi0_dma_isr,
    }
};

static sd_card_t sd_cards[] = {
    {
        .pcName   = "0:",
        .spi      = &spis[0],
        .ss_gpio  = 21,        /* GP21 = CS on Olimex RP2040-PICO-PC */
        .m_Status = STA_NOINIT,
    }
};

/* Required DMA ISR — routes the interrupt to the SPI handler */
void spi0_dma_isr(void) { spi_irq_handler(&spis[0]); }

size_t     spi_get_num(void)          { return 1; }
spi_t     *spi_get_by_num(size_t n)  { return n < 1 ? &spis[n] : NULL; }
size_t     sd_get_num(void)           { return 1; }
sd_card_t *sd_get_by_num(size_t n)   { return n < 1 ? &sd_cards[n] : NULL; }
