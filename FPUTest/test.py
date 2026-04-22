import sys
import subprocess
import atexit


process = subprocess.Popen("cTest/test", stdin=subprocess.PIPE, stdout=subprocess.PIPE)

data1 = 0x3ff00000000000c5
data2 = 0xbd28a404211fb72b

# dataIn1 = "{0:016X}\n".format(data1).encode()
# dataIn2 = "{0:016X}\n".format(data2).encode()
dataIn1 = (str(data1) + "\n").encode()
dataIn2 = (str(data2) + "\n").encode()
process.stdin.write(dataIn1)
process.stdin.flush()
process.stdin.write(dataIn2)
process.stdin.flush()

z = int(process.stdout.readline())
process.terminate()
print(hex(z))
