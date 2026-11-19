import sys
from pathlib import Path
import numpy as np
import pandas as pd

AS = 8

def main():
    if len(sys.argv) != 2:
        print("usage: python3 tb_systolic_array_verify.py <run_dir>")
        return 2

    run_dir = Path(sys.argv[1])
    inputs_df = pd.read_csv(run_dir / "inputs.csv")
    output_df = pd.read_csv(run_dir / "outputs.csv")

    aT_cols = [f"aT{i}" for i in range(AS)]
    b_cols  = [f"b{i}" for i in range(AS)]
    c_cols  = [f"c{i}" for i in range(AS)]

    expected = {}
    for tile, group in inputs_df.groupby("tile"):
        expected[tile] = group[aT_cols].to_numpy().T @ group[b_cols].to_numpy()

    got_tiles = set(output_df["tile"])
    fails = 0
    if got_tiles != set(expected):
        print(f"tile mismatch: inputs {sorted(expected)} vs outputs {sorted(got_tiles)}")
        fails += 1

    for tile, group in output_df.groupby("tile"):
        got = group[c_cols].to_numpy()
        if tile in expected and np.array_equal(got, expected[tile]):
            print(f"tile {tile}: PASS")
        else:
            fails += 1
            print(f"tile {tile}: FAIL")
            print("expected:\n", expected.get(tile))
            print("got:\n", got)

    print(f"{len(expected) - fails}/{len(expected)} tiles passed")
    return 1 if fails else 0

sys.exit(main())