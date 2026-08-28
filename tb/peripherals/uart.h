/*************************************************
 *File----------uart.h
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Monday Jul 13, 2026 14:42:04 EDT
 *License-------GNU GPL-3.0
 ************************************************/
#ifndef UART_H
#define UART_H

#include <arpa/inet.h>
#include <thread>

class UARTSIM {
        unsigned int  bauds;

        unsigned char tx_data[1024];
        unsigned int  tx_data_wPtr;
        unsigned int  tx_data_rPtr;

        // TCP Socket
        int listening_socket;
        sockaddr_in listener_hint{};
        sockaddr_in client_hint{};
        int client_socket;

        std::thread recv_thread;

        void recv_tcp_data();
        void sendchar(const unsigned char c);
        void uartRxd(const unsigned char rxd);
        unsigned char uartTxd();
public:
        UARTSIM(const unsigned int bauds);
        int create_socket(const unsigned short port);
        void close_socket();
        unsigned char operator()(const unsigned char rxd);
};

#endif

