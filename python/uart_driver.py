"""
uart_driver.py

Protocol (must match the control FSM on the FPGA):
  PC to FPGA: 32 bytes
      16 bytes of matrix A, then 16 bytes of matrix B.
      Each matrix is sent row by row and left to right with LSB first
      Each value is a signed 8-bit integer (-128 to 127)
  FPGA to PC: 64 bytes
      16 results, row by row, each a signed 32-bit integer
      sent LSB first

To find the board's port, run in a terminal:
    python -m serial.tools.list_ports
"""

import numpy as np
import serial  ##his is the UART library fyi, just pip install it

TILE_SIZE = 4                                  # the array is 4x4
NUM_ELEMENTS = TILE_SIZE * TILE_SIZE          # 16 values per tile
BYTES_PER_RESULT = 4                           # results are 32-bit
SEND_BYTES = 2 * NUM_ELEMENTS                 # A and B: 32 bytes
RECEIVE_BYTES = NUM_ELEMENTS * BYTES_PER_RESULT  # 64 bytes

INT8_MIN = -128
INT8_MAX = 127


def pack_tiles(A, B):  ##fpga expects 32 bytes, so turn 2 4x4 INT8 matrices 
    message = bytearray()

    for matrix, name in [(A, "A"), (B, "B")]:
        matrix = np.asarray(matrix)
        if matrix.shape != (TILE_SIZE, TILE_SIZE):  ##CHECKS FOR SHAPE
            raise ValueError(f"{name} must be 4x4, got shape {matrix.shape}")

        for row in range(TILE_SIZE):
            for col in range(TILE_SIZE):
                value = int(matrix[row, col]) ##CHECKS FOR INT8 RANGE (SIGNED)
                if value < INT8_MIN or value > INT8_MAX:
                    raise ValueError(
                        f"{name}[{row}][{col}] = {value} is outside the INT8 range "
                        f"{INT8_MIN} to {INT8_MAX}"
                    )
                message += value.to_bytes(1, byteorder="little", signed=True)

    return bytes(message)


def unpack_result(raw):  ##turns the fpga's 64 byte result back into a 4x4 matrix
    if len(raw) != RECEIVE_BYTES:
        raise IOError(
            f"FPGA sent only {len(raw)} of {RECEIVE_BYTES} bytes before the timeout. "
            "Check the board connection, port, and baud rate."
        )

    result = np.zeros((TILE_SIZE, TILE_SIZE), dtype=np.int64)
    for index in range(NUM_ELEMENTS):
        start = index * BYTES_PER_RESULT
        chunk = raw[start:start + BYTES_PER_RESULT]
        value = int.from_bytes(chunk, byteorder="little", signed=True)
        row = index // TILE_SIZE
        col = index % TILE_SIZE
        result[row, col] = value

    return result


class FPGA:

    def __init__(self, port, baud=115200, timeout=2.0):
        # baud must match the BAUD parameter in uart_rx.sv and uart_tx.sv.
        # timeout: seconds to wait for a reply before giving up.
        self.ser = serial.serial_for_url(port, baudrate=baud, timeout=timeout)
        # Throw away any stale bytes left over from an earlier run.
        self.ser.reset_input_buffer()

    def send_tiles(self, A, B):
        self.ser.write(pack_tiles(A, B))   ##Sends 1 of the 4x4 tiles (not both)

    def read_result(self):
        raw = self.ser.read(RECEIVE_BYTES)  ##waits for fpga's 4x4 result tile and returns it 
        return unpack_result(raw)

    def matmul(self, A, B):   ##multiplies two 4x4 INT8 tile on the fpga
        self.send_tiles(A, B)
        return self.read_result()

    def close(self):
        self.ser.close()

