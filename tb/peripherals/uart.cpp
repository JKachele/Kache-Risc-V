/*************************************************
 *File----------uart.cpp
 *Project-------Kache-Risc-V
 *Author--------Justin Kachele
 *Created-------Monday Jul 13, 2026 14:42:33 EDT
 *License-------GNU GPL-3.0
 ************************************************/

#include <cstdio>
#include <iostream>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netdb.h>
#include "uart.h"

UARTSIM::UARTSIM(const unsigned int clksPerBaud) {
        bauds = clksPerBaud;
        tx_data_wPtr = 0;
        tx_data_rPtr = 0;
}

void UARTSIM::recv_tcp_data() {
        char buf[4096];
        for (;;) {
                // Clear buffer
                memset(buf, 0, 4096);

                // Wait for message
                int bytesRecv = recv(client_socket, buf, 4096, 0);
                if (bytesRecv == -1) {
                        std::cerr << "Error in recv(). Quitting\n";
                        break;
                }

                if (bytesRecv == 0) {
                        // std::cout << "Client disconnected" << std::endl;
                        break;
                }

                // Display message
                // std::cout << "Received: " << std::string(buf, 0, bytesRecv);
                // std::cout << std::flush;

                // Add message to transmit queue
                for (int i = 0; i < bytesRecv; i++) {
                        tx_data[tx_data_wPtr] = buf[i];
                        tx_data_wPtr = (tx_data_wPtr + 1) % sizeof(tx_data);
                }
        }
}

int UARTSIM::create_socket(const unsigned short port) {
        // Create a socket
        listening_socket = socket(AF_INET, SOCK_STREAM, 0);
        if (listening_socket < 0) {
                std::cerr << "Can't create a socket! Quitting\n";
                return -1;
        }
        struct linger repo;
        repo.l_onoff = 1; // Enable linger option
        repo.l_linger = 0; // Timeout interval = 0 (forces RST)
        setsockopt(listening_socket, SOL_SOCKET, SO_LINGER, &repo, sizeof(repo));

        // Bind socket to an IP/port
        listener_hint.sin_family = AF_INET;
        listener_hint.sin_port = htons(port);
        inet_pton(AF_INET, "0.0.0.0", &listener_hint.sin_addr);

        if (bind(listening_socket, (struct sockaddr*)&listener_hint, sizeof(listener_hint)) < 0) {
                std::cerr << "Can't bind to IP/port\n";
                close(listening_socket);
                return -1;
        }

        // Mark socket for listening
        if (listen(listening_socket, 5) < 0) {
                std::cerr << "Can't listen!\n";
                close(listening_socket);
                return -1;
        }

        // Accept a connection
        socklen_t client_size = sizeof(client_hint);
        client_socket = accept(listening_socket, (struct sockaddr*)&client_hint, &client_size);
        if (client_socket < 0) {
                std::cerr << "Problem with client connecting!\n";
                close(listening_socket);
                return -1;
        }
        setsockopt(client_socket, SOL_SOCKET, SO_LINGER, &repo, sizeof(repo));

        // Close the listening socket
        close(listening_socket);

        // Start a thread to receive data from the client
        recv_thread = std::thread(&UARTSIM::recv_tcp_data, this);

        return 0;
}

void UARTSIM::close_socket() {
        // Stop data tramsission and send FIN packet to client
        if (shutdown(client_socket, SHUT_RDWR) < 0) {
                std::cerr << "Error shutting down client socket\n";
                close(client_socket);
                return;
        }

        // Recieve any remaining data from the client until the connection is closed
        char buffer[1024];
        ssize_t bytes_received;
        while ((bytes_received = recv(client_socket, buffer, sizeof(buffer), 0)) > 0) {
                // Process the received data if needed
        }

        if (bytes_received < 0) {
                std::cerr << "Error receiving data from client\n";
        }

        // Release the socket resources
        close(client_socket);
        recv_thread.join();
}

void UARTSIM::uartRxd(const unsigned char rxd) {
        static bool isReceiving = false;
        static unsigned int  baud_counter = 0;
        static unsigned int  bit_counter = 0;
        static unsigned char last_rxd = 1;
        static unsigned char rx_data = 0;

        if (!isReceiving) {
                if (rxd == 0 && last_rxd == 1) {
                        isReceiving = true;
                        baud_counter = bauds / 2; // Sample at the middle of the bit period
                        bit_counter = 0;
                        rx_data = 0;
                }
        } else {
                if (baud_counter == 0) {
                        if (bit_counter == 0) {
                                // Start bit, do nothing
                        } else if (bit_counter == 9) {
                                // Stop bit, Print the received byte and reset the state
                                // Send crlf to client for newline characters
                                if (rx_data == '\n' || rx_data == '\r') {
                                        rx_data = '\r';
                                        send(client_socket, &rx_data, 1, 0);
                                        rx_data = '\n';
                                        send(client_socket, &rx_data, 1, 0);
                                } else {
                                        send(client_socket, &rx_data, 1, 0);
                                }
                                isReceiving = false;
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

unsigned char UARTSIM::uartTxd() {
        static bool isTransmitting = false;
        static unsigned int  baud_counter = 0;
        static unsigned int  bit_counter = 0;
        static unsigned char bit_mask = 0;
        static unsigned char txd = 1;

        if (!isTransmitting) {
                if (tx_data_rPtr != tx_data_wPtr) {
                        isTransmitting = true;
                        baud_counter = bauds - 1;
                        bit_counter = 0;
                        bit_mask = 0x01; // Start with the least significant bit
                        txd = 0; // Start bit
                } else {
                        txd = 1; // Idle state
                }
        } else {
                if (baud_counter == 0) {
                        if (bit_counter < 8) {
                                // Send current bit
                                txd = (tx_data[tx_data_rPtr] & bit_mask) ? 1 : 0;
                                bit_mask <<= 1; // Move to the next bit
                        } else if (bit_counter == 8) {
                                // Send Stop bit, update queue and reset state
                                txd = 1;
                                tx_data_rPtr = (tx_data_rPtr + 1) % sizeof(tx_data);
                        } else {
                                isTransmitting = false;
                        }
                        baud_counter = bauds - 1; // Reset the baud counter
                        bit_counter++;
                } else {
                        baud_counter--;
                }
        }

        return txd;
}

unsigned char UARTSIM::operator()(const unsigned char rxd) {
        uartRxd(rxd);
        return uartTxd();
}

