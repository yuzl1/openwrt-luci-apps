#!/usr/bin/env python3
"""Generate an opkg Packages index for every ipk in dist/."""

import glob
import gzip
import hashlib
import io
import os
import sys
import tarfile


def read_control(ipk_path):
    with tarfile.open(ipk_path, "r:gz") as outer:
        inner = outer.extractfile("./control.tar.gz").read()
    with tarfile.open(fileobj=io.BytesIO(inner), mode="r:gz") as control_tar:
        return control_tar.extractfile("./control").read().decode("utf-8")


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "dist"
    entries = []

    for ipk in sorted(glob.glob(os.path.join(out_dir, "*.ipk"))):
        control = read_control(ipk).strip()
        with open(ipk, "rb") as fh:
            data = fh.read()
        control += (
            "\nFilename: ./%s"
            "\nSize: %d"
            "\nSHA256sum: %s\n"
            % (os.path.basename(ipk), len(data), hashlib.sha256(data).hexdigest())
        )
        entries.append(control)

    index = "\n".join(entries)
    if index:
        index += "\n"

    with open(os.path.join(out_dir, "Packages"), "w", encoding="utf-8") as fh:
        fh.write(index)
    with gzip.open(os.path.join(out_dir, "Packages.gz"), "wb") as fh:
        fh.write(index.encode("utf-8"))

    print("indexed %d package(s)" % len(entries))


if __name__ == "__main__":
    main()
