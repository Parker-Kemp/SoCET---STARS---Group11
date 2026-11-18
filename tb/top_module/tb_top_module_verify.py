import sys
from pathlib import Path
import numpy as np
import pandas as pd

def main():
    if len(sys.argv) != 2:
        print("usage: python3 tb_systolic_array_verify.py <run_dir>")
        return 2

    run_dir = Path(sys.argv[1])
    a_df = pd.read_csv(run_dir / "input_a.csv")
    b_df = pd.read_csv(run_dir / "input_b.csv")
    c_df = pd.read_csv(run_dir / "output_c.csv")

    b_groups = dict(tuple(b_df.groupby("test"))) # {test number: that test's rows of B}

    expected = {}
    for test, group_a in a_df.groupby("test"):
        a = group_a.drop(columns="test").to_numpy()
        b = b_groups[test].drop(columns="test").to_numpy()
        expected[test] = a @ b

    got_tests = set(c_df["test"])
    fails = 0
    if got_tests != set(expected):
        print(f"test mismatch: inputs {sorted(expected)} vs outputs {sorted(got_tests)}")
        fails += 1

    for test, group in c_df.groupby("test"):
        got = group.drop(columns="test").to_numpy()
        exp = expected.get(test)

        if exp is not None and np.array_equal(got, exp):
            print(f"test {test}: PASS")
        else:
            fails += 1
            if exp is None or got.shape != exp.shape:
                print(f"test {test}: FAIL (shape {got.shape}, expected {None if exp is None else exp.shape})")
            else:
                bad = np.argwhere(got != exp)
                print(f"test {test}: FAIL, {len(bad)} wrong values, first few (row, col): {bad[:5].tolist()}")
                import matplotlib.pyplot as plt
                plt.imshow(got != exp, cmap="gray_r")   # black = wrong
                plt.title(f"test {test}")
                plt.grid()
                plt.savefig(run_dir / f"diff_test{test}.png")
                plt.close()

    print(f"{len(expected) - fails}/{len(expected)} tests passed")
    return 1 if fails else 0

sys.exit(main())