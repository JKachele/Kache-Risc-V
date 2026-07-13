/*************************************************
 *File----------uart.cpp
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Monday Jul 13, 2026 14:42:33 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include <cstdio>
#include "uart.h"

UARTSIM::UARTSIM(const unsigned int clksPerBaud) {
        state = UART_IDLE;
        bauds = clksPerBaud;
        baud_counter = 0;
        bit_counter = 0;
        last_rxd = 1;
        rx_data = 0;
}

void UARTSIM::operator()(const unsigned char rxd) {
        if (state == UART_IDLE) {
                if (rxd == 0 && last_rxd == 1) {
                        state = UART_RXD;
                        baud_counter = bauds / 2; // Sample at the middle of the bit period
                        bit_counter = 0;
                        rx_data = 0;
                }
        } else if (state == UART_RXD) {
                if (baud_counter == 0) {
                        if (bit_counter == 0) {
                                // Start bit, do nothing
                        } else if (bit_counter == 9) {
                                // Stop bit, Print the received byte and reset the state
                                printf("%c", rx_data);
                                std::fflush(stdout);
                                state = UART_IDLE;
                        } else {
                                rx_data |= (rxd << (bit_counter - 1)); // Store the received bit
                        }
                        baud_counter = bauds - 1; // Reset the baud counter
                        bit_counter++;
                } else {
                        baud_counter--;
                }
        }
        last_rxd = rxd;
}

