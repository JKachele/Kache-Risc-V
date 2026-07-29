#!/usr/bin/env bash

iverilog -o mmuTB MMU_TB.v ../../src/Memory/MMU/*.v
vvp mmuTB
