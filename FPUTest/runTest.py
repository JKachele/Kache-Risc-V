#!/usr/bin/env python

import sys
import subprocess
import atexit
import struct
from random import randint
from random import seed

# Output File
outputFileName = "FailedTests.txt"
outputFile = open(outputFileName, "w")
def output(*s, sep=" ", end="\n", tab=0):
    indent = "    " * tab
    outputFile.write(indent + sep.join(map(str, s)) + end)

children = []
def cleanup():
    for child in children:
        print("Terminating child process")
        child.terminate()
atexit.register(cleanup)

def compile():
    subprocess.call("iverilog -o testBench_tb testBench.v testBench_tb.v ../src/Processor/FPU/*.v", shell=True)
    subprocess.call("gcc -o cTest/test cTest/test.c -lm", shell=True)

def max_or_min(x):
    return x == 0xffffffff or x == 0x7fffffff

def get_mantissa(x):
    return x & 0x000fffffffffffff

def get_exponent(x):
    return ((x & 0x7ff0000000000000) >> 52) - 1023

def get_sign(x):
    return ((x & 0x8000000000000000) >> 63)

def is_nan(x):
    return get_exponent(x) == 1024 and get_mantissa(x) != 0

def is_inf(x):
    return get_exponent(x) == 1024 and get_mantissa(x) == 0

def is_pos_inf(x):
    return is_inf(x) and not get_sign(x)

def is_neg_inf(x):
    return is_inf(x) and get_sign(x)

def match(x, y):
    return (
        (is_pos_inf(x) and is_pos_inf(y)) or
        (is_neg_inf(x) and is_neg_inf(y)) or
        (is_nan(x) and is_nan(y)) or
        (x == y)
        )

def run_test(stimulus_a, stimulus_b, stimulus_c):

    process = subprocess.Popen("cTest/test", stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    children.append(process)
    stim_a = open("stim_a", 'w');
    stim_b = open("stim_b", 'w');
    stim_c = open("stim_c", 'w');
    expected_responses = []
    for a, b, c in zip(stimulus_a, stimulus_b, stimulus_c):
    # for a, b in zip(stimulus_a, stimulus_b):
        dataIn1 = (str(a) + "\n").encode()
        dataIn2 = (str(b) + "\n").encode()
        dataIn3 = (str(c) + "\n").encode()
        hexData1 = "{0:016X}\n".format(a)
        hexData2 = "{0:016X}\n".format(b)
        hexData3 = "{0:016X}\n".format(c)
        process.stdin.write(dataIn1)
        process.stdin.flush()
        process.stdin.write(dataIn2)
        process.stdin.flush()
        process.stdin.write(dataIn3)
        process.stdin.flush()
        stim_a.write(hexData1)
        stim_b.write(hexData2)
        stim_c.write(hexData3)
        z = int(process.stdout.readline())
        expected_responses.append(z)

    emptyLines = 1000 - len(stimulus_a)
    for i in range(emptyLines):
        stim_a.write("XXXXXXXXXXXXXXXX\n")
        stim_b.write("XXXXXXXXXXXXXXXX\n")
        stim_c.write("XXXXXXXXXXXXXXXX\n")

    process.terminate()
    children.remove(process)

    stim_a.close()
    stim_b.close()
    stim_c.close()


    process = subprocess.Popen("./testBench_tb", shell=True)
    children.append(process)
    process.wait()
    children.remove(process)

    stim_z = open("resp_z");
    actual_responses = []
    for value in stim_z:
        actual_responses.append(int(value, 16))

    if len(actual_responses) < len(expected_responses):
        print("Fail ... not enough results")
        exit(0)

    # print([hex(i) for i in expected_responses])
    # print([hex(i) for i in actual_responses])

    failed = 0
    for expected, actual, a, b, c in zip(expected_responses, actual_responses, stimulus_a, stimulus_b, stimulus_c):
    # for expected, actual, a, b in zip(expected_responses, actual_responses, stimulus_a, stimulus_b):
        passed = match(expected, actual)

        # if(expected != actual):
        #     # expected_mantissa =   expected & 0x000fffffffffffff
        #     # expected_exponent = ((expected & 0x7ff0000000000000) >> 52) - 1023
        #     # expected_sign     = ((expected & 0x8000000000000000) >> 63)
        #     # actual_mantissa   =     actual & 0x000fffffffffffff
        #     # actual_exponent   = ((  actual & 0x7ff0000000000000) >> 52) - 1023
        #     # actual_sign       = ((  actual & 0x8000000000000000) >> 63)
        #     # if expected_exponent == 1024 and expected_mantissa != 0:
        #     #     if(actual_exponent == 1024):
        #     #         passed = True
        #     # else:
        #         # passed = False
        #     passed = False
        # else:
        #     passed = True

        if not passed:
            failed += 1

            output("Fail ... expected:", hex(expected), "actual:", hex(actual))

            aFloat = struct.unpack('!d', struct.pack('!Q', a))[0]
            bFloat = struct.unpack('!d', struct.pack('!Q', b))[0]
            cFloat = struct.unpack('!d', struct.pack('!Q', c))[0]
            expFloat = struct.unpack('!d', struct.pack('!Q', expected))[0]
            actFloat = struct.unpack('!d', struct.pack('!Q', actual))[0]

            output("A:", hex(a), "(", aFloat, ")")
            output("a mantissa:",                 a & 0x000fffffffffffff, tab=1)
            output("a exponent:",               ((a & 0x7ff0000000000000) >> 52) - 1023, tab=1)
            output("a sign:",                   ((a & 0x8000000000000000) >> 63), tab=1)
            # output("a mantissa:",                 a & 0x007fffff, tab=1)
            # output("a exponent:",               ((a & 0x7f800000) >> 23) - 127, tab=1)
            # output("a sign:",                   ((a & 0x80000000) >> 31), tab=1)

            output("B:", hex(b), "(", bFloat, ")")
            output("b mantissa:",                 b & 0x000fffffffffffff, tab=1)
            output("b exponent:",               ((b & 0x7ff0000000000000) >> 52) - 1023, tab=1)
            output("b sign:",                   ((b & 0x8000000000000000) >> 63), tab=1)

            output("C:", hex(c), "(", cFloat, ")")
            output("c mantissa:",                 c & 0x000fffffffffffff, tab=1)
            output("c exponent:",               ((c & 0x7ff0000000000000) >> 52) - 1023, tab=1)
            output("c sign:",                   ((c & 0x8000000000000000) >> 63), tab=1)

            output()

            # output("Expected", expected)
            output("Expected:", hex(expected), "(", expFloat, ")")
            output("expected mantissa:",   expected & 0x000fffffffffffff, tab=1)
            output("expected exponent:", ((expected & 0x7ff0000000000000) >> 52) - 1023, tab=1)
            output("expected sign:",     ((expected & 0x8000000000000000) >> 63), tab=1)
            # output("expected mantissa:",   expected & 0x007fffff, tab=1)
            # output("expected exponent:", ((expected & 0x7f800000) >> 23) - 127, tab=1)
            # output("expected sign:",     ((expected & 0x80000000) >> 31), tab=1)

            # output("Actual  ", actual)
            output("Actual:  ", hex(actual), "(", actFloat, ")")
            output("actual mantissa:",       actual & 0x000fffffffffffff, tab=1)
            output("actual exponent:",     ((actual & 0x7ff0000000000000) >> 52) - 1023, tab=1)
            output("actual sign:",         ((actual & 0x8000000000000000) >> 63), tab=1)
            # output("actual mantissa:",   actual & 0x007fffff, tab=1)
            # output("actual exponent:", ((actual & 0x7f800000) >> 23) - 127, tab=1)
            # output("actual sign:",     ((actual & 0x80000000) >> 31), tab=1)

            output("----------------------------------------------------------------")
            # sys.exit(0)
    return failed

compile()
count = 0
failed = 0

# #regression tests
# stimulus_a = [0x3ff00000000000c5, 0xff80000000000000, 0x7f80000000000000]
# stimulus_b = [0xbd28a404211fb72b, 0x7f80000000000000, 0xff80000000000000]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# #corner cases
# from itertools import permutations
# stimulus_a = [int(i[0]) for i in permutations([
#         0x8000000000000000, 
#         0x0000000000000000, 
#         0x7ff8000000000000, 
#         0xfff8000000000000, 
#         0x7ff0000000000000, 
#         0xfff0000000000000
# ], 2)]
# stimulus_b = [int(i[1]) for i in permutations([
#         0x8000000000000000,
#         0x0000000000000000,
#         0x7ff8000000000000,
#         0xfff8000000000000,
#         0x7ff0000000000000,
#         0xfff0000000000000
# ], 2)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# #edge cases
# stimulus_a = [0x8000000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_a = [0x0000000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0x8000000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0x0000000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_a = [0x7FF8000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_a = [0xFFF8000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0x7FF8000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64) for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0xFFF8000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64) for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_a = [0x7FF0000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_a = [0xFFF0000000000000 for i in range(1000)]
# stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0x7FF0000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# stimulus_b = [0xFFF0000000000000 for i in range(1000)]
# stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
# failed += run_test(stimulus_a, stimulus_b)
# count += len(stimulus_a)
# print(count, "vectors tested", failed, "failed")
#
# #seed(0)
# for i in range(100):
#     stimulus_a = [randint(0, 1<<64) for i in range(1000)]
#     stimulus_b = [randint(0, 1<<64) for i in range(1000)]
#     failed += run_test(stimulus_a, stimulus_b)
#     count += 1000
#     print(count, "vectors tested", failed, "failed")

#regression tests
stimulus_a = [0xff80000000000000, 0x7f186e6afb58b747]
stimulus_b = [0x7f80000000000000, 0xea03b2d46982bc10]
stimulus_c = [0xbd28a404211fb72b, 0x7ff0000000000000]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

#corner cases
from itertools import permutations
stimulus_a = [int(i[0]) for i in permutations([
    0x8000000000000000, 
    0x0000000000000000, 
    0x7ff8000000000000, 
    0xfff8000000000000, 
    0x7ff0000000000000, 
    0xfff0000000000000
], 3)]
stimulus_b = [int(i[1]) for i in permutations([
    0x8000000000000000, 
    0x0000000000000000, 
    0x7ff8000000000000, 
    0xfff8000000000000, 
    0x7ff0000000000000, 
    0xfff0000000000000
], 3)]
stimulus_c = [int(i[2]) for i in permutations([
    0x8000000000000000, 
    0x0000000000000000, 
    0x7ff8000000000000, 
    0xfff8000000000000, 
    0x7ff0000000000000, 
    0xfff0000000000000
], 3)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

#edge cases
stimulus_a = [0x8000000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [0x0000000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [0x8000000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [0x0000000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0x8000000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0x0000000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [0x7FF8000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [0xFFF8000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64) for i in range(1000)]
stimulus_b = [0x7FF8000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64) for i in range(1000)]
stimulus_b = [0xFFF8000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0x7FF8000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0xFFF8000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [0x7FF0000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [0xFFF0000000000000 for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [0x7FF0000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [0xFFF0000000000000 for i in range(1000)]
stimulus_c = [randint(0, 1<<64)  for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0x7FF0000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = [randint(0, 1<<64)  for i in range(1000)]
stimulus_c = [0xFFF0000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

stimulus_a = [randint(0, 1<<64)  for i in range(1000)]
stimulus_b = stimulus_a
stimulus_c = [0x0000000000000000 for i in range(1000)]
failed += run_test(stimulus_a, stimulus_b, stimulus_c)
count += len(stimulus_a)
print(count, "vectors tested", failed, "failed")

#seed(0)
for i in range(1000):
    stimulus_a = [randint(0, 1<<64) for i in range(1000)]
    stimulus_b = [randint(0, 1<<64) for i in range(1000)]
    stimulus_c = [randint(0, 1<<64) for i in range(1000)]
    failed += run_test(stimulus_a, stimulus_b, stimulus_c)
    count += 1000
    print(count, "vectors tested", failed, "failed")

outputFile.close()
