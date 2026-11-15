"""
uart_driver.py

Sends two matrices to the FPGA, read result back, compares it with Numpy baseline.

PC to FPGA:  tiles_m, tiles_n, tiles_q (1 byte each), then A words, then B words
FPGA to PC:  C words, each value a signed INT32 sent LSB

Run from the repo's top folder (VS Code terminal):
    python -m serial.tools.list_ports                      #find the board's COM port
    python python/uart_driver.py --port COM5 --size 20 13 30
"""

import argparse
import time
import numpy as np
import serial   

AS = 8 #array side length, must match hardware Rx/Tx
MAX = 256 #largest matrix side the FPGA memory holds
MIN_TILES_N = 2 #workaround for the tiles_n = 1 hardware bug, set to 1 once fixed


def ceil_div(a, b): #division op that rounds up
    return (a + b - 1) // b


def build_message(A, B): ##Pads A and B tiles to send
    m, n = A.shape
    q = B.shape[1]
    tiles_m = ceil_div(m, AS)
    tiles_n = max(ceil_div(n, AS), MIN_TILES_N)
    tiles_q = ceil_div(q, AS)

    #Creates all zero matrix and copies values into top-left
    A_pad = np.zeros((tiles_m * AS, tiles_n * AS), dtype=np.int64)
    A_pad[:m, :n] = A
    B_pad = np.zeros((tiles_n * AS, tiles_q * AS), dtype=np.int64)
    B_pad[:n, :q] = B

    message = bytearray([tiles_m, tiles_n, tiles_q])   #header

    for fi in range(tiles_m):
        for fk in range(tiles_n):
            tile = A_pad[fi * AS:(fi + 1) * AS, fk * AS:(fk + 1) * AS]
            for col in range(AS):
                for value in tile[:, col]:
                    message += int(value).to_bytes(1, "little", signed=True)

    for fj in range(tiles_q):
        for fk in range(tiles_n):
            tile = B_pad[fk * AS:(fk + 1) * AS, fj * AS:(fj + 1) * AS]
            for row in range(AS):
                for value in tile[row, :]:
                    message += int(value).to_bytes(1, "little", signed=True)

    return bytes(message), (tiles_m, tiles_n, tiles_q)


def unpack_c(raw, tiles, m, q): #crops received C matrix from FPGA to m x q
    tiles_m, tiles_n, tiles_q = tiles
    C_pad = np.zeros((tiles_m * AS, tiles_q * AS), dtype=np.int64)
    pos = 0
    for wi in range(tiles_m):
        for wj in range(tiles_q):
            for row in range(AS):
                for col in range(AS):
                    value = int.from_bytes(raw[pos:pos + 4], "little", signed=True)
                    C_pad[wi * AS + row, wj * AS + col] = value
                    pos += 4
    return C_pad[:m, :q]


def read_exactly(ser, count): #reads until count bytes are received
    data = bytearray()
    while len(data) < count:
        chunk = ser.read(count - len(data))
        if len(chunk) == 0:
            raise IOError(f"FPGA stopped after {len(data)} of {count} bytes. "
                          "Check the port, baud rate, and reset the board.")
        data += chunk
    return bytes(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, help="e.g. COM5")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--size", type=int, nargs=3, default=[16, 16, 16],
                        metavar=("M", "N", "Q"), help="A is MxN, B is NxQ")
    args = parser.parse_args()

    m, n, q = args.size
    for size in (m, n, q):
        if size < 1 or size > MAX:
            parser.error(f"sizes must be between 1 and {MAX}")

    #creates random INT8 matrices
    rng = np.random.default_rng()
    A = rng.integers(-128, 128, size=(m, n))
    B = rng.integers(-128, 128, size=(n, q))

    #Pc calculate timer
    pc_start = time.perf_counter()
    C_pc = A @ B
    pc_time = time.perf_counter() - pc_start

    #FPGA calculate timer
    message, tiles = build_message(A, B)
    c_bytes = tiles[0] * tiles[2] * AS * AS * 4

    ser = serial.Serial(args.port, args.baud, timeout=2.0)
    ser.reset_input_buffer()            #flushes leftover bytes

    fpga_start = time.perf_counter()
    ser.write(message)
    raw = read_exactly(ser, c_bytes)
    fpga_time = time.perf_counter() - fpga_start
    ser.close()

    C_fpga = unpack_c(raw, tiles, m, q)

    #Print results
    wrong = int(np.count_nonzero(C_fpga != C_pc))

    print(f"A {m}x{n} @ B {n}x{q}   tiles {tiles}")
    print(f"sent {len(message)} bytes, received {len(raw)} bytes")
    print(f"wrong values: {wrong} of {C_pc.size}")
    print(f"PC (NumPy) time:     {pc_time * 1000:.3f} ms")
    print(f"FPGA round-trip time: {fpga_time * 1000:.1f} ms (includes UART transfer)")


if __name__ == "__main__":
    main()
