/*************************************************
 *File----------uart.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Monday Jul 13, 2026 14:42:04 EDT
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef UART_H
#define UART_H

class UARTSIM {
	typedef	enum {
                UART_IDLE,
                UART_RXD
	} UART_STATE;

        UART_STATE state;
        unsigned int  bauds;
        unsigned int  baud_counter;
        unsigned char last_rxd;
        unsigned int  bit_counter;
        unsigned char rx_data;
public:
        UARTSIM(const unsigned int bauds);
        void operator()(const unsigned char rxd);
};

#endif

