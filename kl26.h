/*                                      */
/*                                      */
/* ARMv6M Architecture Reference Manual */
/*                                      */
/*                                      */

#define ACTLR       0xE000E008

#define SYST_CSR    0xE000E010
#define SYST_RVR    0xE000E014
#define SYST_CVR    0xE000E018
#define SYST_CALIB  0xE000E01C

#define NVIC_ISER   0xE000E100
#define NVIC_ICER   0xE000E180
#define NVIC_ISPR   0xE000E200
#define NVIC_ICPR   0xE000E280
#define NVIC_IPR(x) (0xE000E400 + ((x) << 2))

#define CPUID       0xE000ED00
#define ICSR        0xE000ED04
#define VTOR        0xE000ED08
#define AIRCR       0xE000ED0C

#define SCR         0xE000ED10
#define CCR         0xE000ED14
#define SHPR2       0xE000ED1C
#define SHPR3       0xE000ED20

#define SHCSR       0xE000ED24
#define DFSR        0xE000ED30

/*                                  */
/*                                  */
/* KL26 Sub-Family Reference Manual */
/*                                  */
/*                                  */

/*                                               */
/* Chapter 11: Port control and interrupt (PORT) */
/*                                               */

#define PORTA       0x40049000
#define PORTB       0x4004A000
#define PORTC       0x4004B000
#define PORTD       0x4004C000
#define PORTE       0x4004D000

#define PCR(x)      ((x) << 2)
#define GPCLR       0x80
#define GPCHR       0x84
#define ISFR        0xA0

/*                                             */
/* Chapter 12: System Integration Module (SIM) */
/*                                             */

#define SIM_SOPT1       0x40047000
#define SIM_SOPT1CFG    0x40047004

/* Base address */
#define SIM         0x40048000

/*      Nothing at  0x40048000 */
#define SIM_SOPT2   0x40048004
/*      Nothing at  0x40048008 */
#define SIM_SOPT4   0x4004800C

#define SIM_SOPT5   0x40048010
/*      Nothing at  0x40048014 */
#define SIM_SOPT7   0x40048018
/*      Nothing at  0x4004801C */

/*      Nothing at  0x40048020 */
#define SIM_SDID    0x40048024
/*      Nothing at  0x40048028 */
/*      Nothing at  0x4004802C */

/*      Nothing at  0x40048030 */
#define SIM_SCGC4   0x40048034
#define SIM_SCGC5   0x40048038
#define SIM_SCGC6   0x4004803C

#define SIM_SCGC7   0x40048040
#define SIM_CLKDIV1 0x40048044
/*      Nothing at  0x40048048 */
#define SIM_FCFG1   0x4004804C

#define SIM_FCFG2   0x40048050
/*      Nothing at  0x40048054 */
#define SIM_UIDMH   0x40048058
#define SIM_UIDML   0x4004805C

#define SIM_UIDL    0x40048060

#define SIM_COPC    0x40048100
#define SIM_SRVCOP  0x40048104

/*                                                */
/* Chapter 24: Multipurpose Clock Generator (MCG) */
/*                                                */

/* Base address */
#define MCG         0x40064000

#define MCG_C1      0x40064000
#define MCG_C2      0x40064001
#define MCG_C3      0x40064002
#define MCG_C4      0x40064003

#define MCG_C5      0x40064004
#define MCG_C6      0x40064005
#define MCG_S       0x40064006
/*      Nothing at  0x40064007 */

#define MCG_SC      0x40064008
/*      Nothing at  0x40064009 */
#define MCG_ATCVH   0x4006400A
#define MCG_ATCVL   0x4006400B

#define MCG_C7      0x4006400C
#define MCG_C8      0x4006400D
#define MCG_C9      0x4006400E
#define MCG_C10     0x4006400F

/*                              */
/* Chapter 25: Oscillator (OSC) */
/*                              */

#define OSC0_CR     0x40065000

/*                                                          */
/* Chapter 35: Universal Serial Bus OTG Controller (USBOTG) */
/*                                                          */

#define USB0_PERID      0x40072000
#define USB0_IDCOMP     0x40072004
#define USB0_REV        0x40072008
#define USB0_ADDINFO    0x4007200C

#define USB0_OTGISTAT   0x40072010
#define USB0_OTGICR     0x40072014
#define USB0_OTGSTAT    0x40072018
#define USB0_OTGCTL     0x4007201C

#define USB0_ISTAT      0x40072080
#define USB0_INTEN      0x40072084
#define USB0_ERRSTAT    0x40072088
#define USB0_ERREN      0x4007208C

#define USB0_STAT       0x40072090
#define USB0_CTL        0x40072094
#define USB0_ADDR       0x40072098
#define USB0_BDTPAGE1   0x4007209C

#define USB0_FRMNUML    0x400720A0
#define USB0_FRMNUMH    0x400720A4
#define USB0_TOKEN      0x400720A8
#define USB0_SOFTHLD    0x400720AC

#define USB0_BDTPAGE2   0x400720B0
#define USB0_BDTPAGE3   0x400720B4

#define USB0_ENDPT(x)   (0x400720C0 + ((x) << 2))

#define USB0_USBCTRL    0x40072100
#define USB0_OBSERVE    0x40072104
#define USB0_CONTROL    0x40072108
#define USB0_USBTRC0    0x4007210C

#define USB0_USBFRMADJUST   0x40072114

/*                                                 */
/* Chapter 42: General-purpose input/output (GPIO) */
/*                                                 */

#define GPIOA       0x400FF000
#define GPIOB       0x400FF040
#define GPIOC       0x400FF080
#define GPIOD       0x400FF0C0
#define GPIOE       0x400FF100

#define FGPIOA      0xF8000000
#define FGPIOB      0xF8000040
#define FGPIOC      0xF8000080
#define FGPIOD      0xF80000C0
#define FGPIOE      0xF8000100

#define GPIO_PDOR   0x00
#define GPIO_PSOR   0x04
#define GPIO_PCOR   0x08
#define GPIO_PTOR   0x0C
#define GPIO_PDIR   0x10
#define GPIO_PDDR   0x14
