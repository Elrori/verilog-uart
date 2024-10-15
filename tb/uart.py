import serial
import time
import subprocess


def crc(crcIn, data):
    class bitwrapper:
        def __init__(self, x):
            self.x = x
        def __getitem__(self, i):
            return (self.x >> i) & 1
        def __setitem__(self, i, x):
            self.x = (self.x | (1 << i)) if x else (self.x & ~(1 << i))
    crcIn = bitwrapper(crcIn)
    data = bitwrapper(data)
    ret = bitwrapper(0)
    ret[0] = crcIn[0] ^ crcIn[6] ^ crcIn[7] ^ data[0] ^ data[6] ^ data[7]
    ret[1] = crcIn[0] ^ crcIn[1] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[6]
    ret[2] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[6]
    ret[3] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[7] ^ data[1] ^ data[2] ^ data[3] ^ data[7]
    ret[4] = crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ data[2] ^ data[3] ^ data[4]
    ret[5] = crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ data[3] ^ data[4] ^ data[5]
    ret[6] = crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[4] ^ data[5] ^ data[6]
    ret[7] = crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ data[5] ^ data[6] ^ data[7]
    return ret.x

def main():

    crc_ret = crc(170,20)
    crc_ret = crc(170,crc_ret)
    crc_ret = crc(170,crc_ret)
    crc_ret = crc_ret.to_bytes(length=1, byteorder='big', signed=False)

    print(f'crc:{crc_ret}')
    baud = 115200
    subprocess.run(f'stty -F /dev/ttyS1 speed {baud} cs8 -parenb -cstopb', shell=True, check=True)
    with serial.Serial("/dev/ttyS1",baudrate=baud,bytesize=serial.EIGHTBITS,stopbits=serial.STOPBITS_ONE,parity=serial.PARITY_NONE,timeout=0.01,) as uart1:
        uart1.write(b"\xaa" + b"\xaa\xaa" + crc_ret)
        if uart1.in_waiting > 0:
            rbuf = uart1.read(uart1.in_waiting)
            print("rbuf:",rbuf)

main()
