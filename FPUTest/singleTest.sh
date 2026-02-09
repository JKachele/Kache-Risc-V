#!/usr/bin/env bash

iverilog -DSINGLE -o testBench_tb testBench.v testBench_tb.v ../src/Processor/FPU/*.v
./testBench_tb
