/* SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 * SPDX-License-Identifier: MIT-0
 * Adapted PLL helpers only from baremetal-drivers66bdcc3. No board recipe,
 * broad firewalls/resets or startup copied. MMIO is injectable for host tests;
 * membus timeout/error now propagates before continuing configuration. */
#define CM_BASE			0x10D10000U
#define CM_CTRL			(CM_BASE + 0x000U)
#define CM_STAT			(CM_BASE + 0x004U)
#define CM_INTRCLR		(CM_BASE + 0x014U)
#define CM_M_BYPASS		(CM_BASE + 0x030U)
#define CM_M_NOCCLK		(CM_BASE + 0x040U)
#define CM_M_NOCDIV		(CM_BASE + 0x044U)
#define CM_M_PLLGLOB		(CM_BASE + 0x048U)
#define CM_M_FDBCK		(CM_BASE + 0x04CU)
#define CM_M_MEM		(CM_BASE + 0x050U)
#define CM_M_MEMSTAT		(CM_BASE + 0x054U)
#define CM_M_VCOCALIB		(CM_BASE + 0x058U)
#define CM_M_PLLC0		(CM_BASE + 0x05CU)
#define CM_M_PLLC1		(CM_BASE + 0x060U)
#define CM_M_PLLC2		(CM_BASE + 0x064U)
#define CM_M_PLLC3		(CM_BASE + 0x068U)
#define CM_M_PLLM		(CM_BASE + 0x06CU)
#define CM_M_LOSTLOCK		(CM_BASE + 0x078U)
#define CM_P_BYPASS		(CM_BASE + 0x088U)
#define CM_P_PLLGLOB		(CM_BASE + 0x09CU)
#define CM_P_FDBCK		(CM_BASE + 0x0A0U)
#define CM_P_MEM		(CM_BASE + 0x0A4U)
#define CM_P_MEMSTAT		(CM_BASE + 0x0A8U)
#define CM_P_VCOCALIB		(CM_BASE + 0x0ACU)
#define CM_P_PLLC0		(CM_BASE + 0x0B0U)
#define CM_P_PLLC1		(CM_BASE + 0x0B4U)
#define CM_P_PLLC2		(CM_BASE + 0x0B8U)
#define CM_P_PLLC3		(CM_BASE + 0x0BCU)
#define CM_P_PLLM		(CM_BASE + 0x0C0U)
#define CM_P_LOSTLOCK		(CM_BASE + 0x0CCU)
#define CM_C_EXTCNTRST		(CM_BASE + 0x0F4U)

#define CM_CTRL_BOOTMODE	(1U << 0)
/* Software-controlled boot clock: enable (bit 8) and select the HPS internal
 * oscillator (bit 9). The real-silicon FSBL path (U-Boot clk-agilex5.c SPL)
 * forces these on before PLL config so the PLL source-sync/membus interface has
 * a running boot clock; without them the membus never acknowledges. ATF's
 * Simics-oriented code omits them because that environment already clocks it. */
#define CM_CTRL_SWBTCLKEN	(1U << 8)
#define CM_CTRL_SWBTCLKSEL	(1U << 9)
#define CM_STAT_BUSY		(1U << 0)
#define CM_STAT_MLOCK		(1U << 8)
#define CM_STAT_PLOCK		(1U << 16)
#define CM_GLOB_PD_N		(1U << 0)
#define CM_GLOB_RST_N		(1U << 1)
#define CM_GLOB_CLR_LL_BYP	(1U << 29)
#define CM_PLLCX_EN		(1U << 27)
#define CM_BYP_MAIN_ALL		0xF6U
#define CM_BYP_PER_ALL		0xEFU
#define CM_LOSTLOCK_BYPCLR	(1U << 0)
#define CM_INTRCLR_MLOST	(1U << 2)
#define CM_INTRCLR_PLOST	(1U << 3)
#define CM_EXTCNTRST_ALL	0x3DEFU

#define CM_MEM_REQ		(1U << 24)
#define CM_MEM_WR		(1U << 25)
#define CM_MEM_WDAT_OFS		16
#define CM_MEM_ADDR_MASK	0xFFFFU
#define CM_MEM_ADDR_START	0x4000U

#define CM_FSM_RETRY		1000U
#define CM_MEM_RETRY		1000U
#define CM_LOCK_RETRY		1000U
#define CM_LOCK_STABLE		5U

static inline uint32_t cm_rd(uint32_t a) { return de25_rd(a); }
static inline void cm_wr(uint32_t a, uint32_t v) { de25_wr(a,v); }
static inline void cm_set(uint32_t a, uint32_t m) { cm_wr(a, cm_rd(a) | m); }
static inline void cm_clr(uint32_t a, uint32_t m) { cm_wr(a, cm_rd(a) & ~m); }

/* Wait for the clock-manager FSM to go idle (BUSY == 0). */
static int cm_wait_fsm(void)
{
	uint32_t c = 0;

	while ((cm_rd(CM_STAT) & CM_STAT_BUSY) != 0U) {
		if (++c >= CM_FSM_RETRY) {
			return -1;
		}
	}
	return 0;
}

/* Mirror of ATF calc_pll_vcocalibration(): MSCNT_CONST=100, HSCNT_CONST=4. */
static uint32_t cm_vcocalib(uint32_t pllm, uint32_t glob)
{
	uint32_t mdiv = pllm & 0x3FFU;
	uint32_t drefclkdiv = (glob >> 12) & 0x3U;
	uint32_t refclkdiv = (glob >> 8) & 0x3FU;
	uint32_t mscnt, hscnt;

	if (mdiv == 0U || refclkdiv == 0U) {
		return 0U;
	}
	mscnt = 100U / (mdiv * (1U << drefclkdiv));
	if (mscnt == 0U) {
		mscnt = 1U;
	}
	hscnt = (mdiv * mscnt * (1U << drefclkdiv) / refclkdiv) - 4U;
	return (hscnt & 0x3FFU) | ((mscnt << 16) & 0xFF0000U);
}

/* Poll the PLL membus until the request bit clears (mirror pll_source_sync_wait). */
static int cm_mem_wait(uint32_t memreg)
{
	uint32_t c = 0;

	while ((cm_rd(memreg) & CM_MEM_REQ) != 0U) {
		if (++c >= CM_MEM_RETRY) {
			return -1;
		}
	}
	return (cm_rd(memreg) & (1U << 26)) ? -1 : 0;
}

/* PLL power-down analog config over the membus (ATF config_pll_pd_state).
 * Entry 0 (source-sync mode) is required to lock. Returns membus timeout count. */
static uint32_t cm_pll_pd_state(uint32_t memreg, uint32_t memstat)
{
	static const struct { uint32_t addr; uint32_t data; uint32_t mask; } cfg[] = {
		{ 0x27U, (1U << 7), (1U << 7) },	/* enable source synchronous mode */
		{ 0xB3U, (1U << 0), (1U << 0) },	/* limit overshoot frequency at lock */
		{ 0xE6U, (1U << 0), (1U << 0) },	/* longer settle before lock asserted */
		{ 0x03U, 0x4AU, 0x7FU },		/* duty cycle, clock slice 0 */
		{ 0x07U, 0x4AU, 0x7FU },		/* duty cycle, clock slice 1 */
	};
	uint32_t timeouts = 0U;

	for (unsigned i = 0; i < (sizeof(cfg) / sizeof(cfg[0])); i++) {
		uint32_t a = (cfg[i].addr | CM_MEM_ADDR_START) & CM_MEM_ADDR_MASK;
		uint32_t r = 0U;

		/* Read-modify-write the membus register. */
		cm_wr(memreg, CM_MEM_REQ | a);
		if (cm_mem_wait(memreg) == 0) {
			r = cm_rd(memstat);
		} else {
			return 1U;
		}
		cm_wr(memreg, CM_MEM_REQ | CM_MEM_WR |
		      ((((r & ~cfg[i].mask) | cfg[i].data) << CM_MEM_WDAT_OFS)) | a);
		if (cm_mem_wait(memreg) != 0) {
			return 1U;
		}
	}
	return timeouts;
}

/* Wait for both PLLs to report a stable lock (mirror wait_pll_lock). */
static int cm_wait_lock(void)
{
	uint32_t c = 0, stable = 0;

	while (c < CM_LOCK_RETRY) {
		if ((cm_rd(CM_STAT) & (CM_STAT_MLOCK | CM_STAT_PLOCK)) ==
		    (CM_STAT_MLOCK | CM_STAT_PLOCK)) {
			if (++stable >= CM_LOCK_STABLE) {
				return 0;
			}
		} else {
			stable = 0;
		}
		c++;
	}
	return -1;
}
