import sys
import argparse
import multiprocessing as mp
from pathlib import Path
import hashlib
from functools import partial

# modes:
# 1. Takes in data from a file and produces a hash, optionally as the text for a `struct sha256state`
# 2. Takes in data from stdin (via a pipe) and produces a hash, optionally as the text for a `struct sha256state`
# 3. Takes in seed data as an argument and a number of problems, and produces data to hash
# 4. Takes in seed data from stdin (via a pipe) and a number of problems, and produces data to hash
# 5. Takes in seed data from a file and a number of problems, and produces data to hash
# 6. Takes in seed data from a file, a number of problems and a number of leading zeros (bits or nibbles) and attempts
#    to find a hash that meets these requirements and produces the correct hash, starting data and optionally the hash
#    as text for a `struct sha256state` for checking

def string_from_stdin_pipe():
    res : list[str] = []
    for line in sys.stdin:
        res.append(line)
    return "".join(res)

def string_from_file(path: Path):
    f = open(path)
    res : list[str] = f.readlines()
    f.close()
    return "".join(res)

def string_from_file_or_stdin(path: Path, use_file: bool):
    global args
    if use_file:
        return string_from_file(path)
    elif args.data != None:
        return args.data
    else:
        return string_from_stdin_pipe()

def bytes_from_hex(text: str, spec: str | None) -> bytes:
    """Decode a hex stream, swapping each word's bytes if `spec` (e.g. 'little32') differs from this machine's endian-ness.
    No swapping happens if `spec` is None (bare --hex) or the data is a single byte."""
    text = "".join(text.split())
    if text[:2].lower() == "0x":
        text = text[2:]
    data = bytes.fromhex(text)
    if spec is None or len(data) == 1:
        return data

    for endian in ("little", "big"):
        if spec.startswith(endian) and spec[len(endian):] in ("16", "32", "64"):
            break
    else:
        raise ValueError(f"Invalid --hex specifier '{spec}', expected one of little16, little32, little64, big16, big32, big64")
    wordbytes = int(spec[len(endian):]) // 8

    if len(data) % wordbytes != 0:
        raise ValueError(f"Hex data is {len(data)} bytes, which is not a multiple of the {wordbytes}-byte word size for '{spec}'")

    if endian != sys.byteorder:
        data = b"".join(data[i:i + wordbytes][::-1] for i in range(0, len(data), wordbytes))
    return data

def load_input(path: Path, use_file: bool) -> bytes:
    text = string_from_file_or_stdin(path, use_file)
    if args.strip:
        text = text.removesuffix("\n").removesuffix("\r")
    if args.hex is not False:
        return bytes_from_hex(text, args.hex)
    return text.encode("utf-8")

def do_hashing(data: bytes, format_as_struct: bool) -> str:
    hasher = hashlib.sha256()
    hasher.update(data)
    hashstring = hasher.hexdigest()
    if format_as_struct:
        return f"{{\n\t0x{hashstring[0:8]},\n\t0x{hashstring[8:16]},\n\t0x{hashstring[16:24]},\n\t0x{hashstring[24:32]},\n\t0x{hashstring[32:40]},\n\t0x{hashstring[40:48]},\n\t0x{hashstring[48:56]},\n\t0x{hashstring[56:64]}\n}}"
    else:
        return hashstring

def show(data: bytes) -> str:
    return data.hex() if args.hex is not False else data.decode("utf-8", errors="replace")

def do_hashgen(seed: bytes, generate: int) -> str:
    res : list[str] = []
    for i in range(generate):
        res.append(show(seed + str(i).encode("ascii")))
    return "\n".join(res)

def starts_with_zeros(hash: bytes, zerobits: int) -> bool:
    return int.from_bytes(hash, 'big') >> (len(hash) * 8 - zerobits) == 0

def check_nonce(seed: bytes, zerobits: int, i: int) -> bool:
    # module level (not nested) so that it can be pickled and sent to worker processes
    hasher = hashlib.sha256()
    hasher.update(seed + str(i).encode("ascii"))
    return starts_with_zeros(hasher.digest(), zerobits)

def do_solving(seed: bytes, generate: int, zerobits: int, processes: int, format_as_struct: bool) -> str:
    with mp.Pool(processes=processes) as pool:
        results = pool.map(partial(check_nonce, seed, zerobits), range(generate))
    try:
        success_index = results.index(True)
        lines = [
            f"Found solution with {zerobits} zero bits with nonce {success_index}, with seed {show(seed)}\n"
            f"Final hash state:\n"
            f"{do_hashing(seed + str(success_index).encode("ascii"), format_as_struct)}"
        ]
        return "".join(lines)
    except ValueError:
        return f"No solution with {zerobits} zero bits found in {generate} nonces with seed {show(seed)}"
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="RedPow CPU PoC",
        description="Implements some hashing functionality required for ReadPoW testing"
    )

    parser.add_argument('-d', '--data'    , type=str           , help="Data to use as input")
    parser.add_argument('-x', '--hex'     , type=str, nargs='?', const=None, default=False, help="If present, treat input as hex data, optionally specifying endian-ness, which swaps bytes if it differs from this machine ('little16', 'little32', 'little64', 'big16', 'big32', 'big64')")
    parser.add_argument('-t', '--strip'   , action="store_true", help="Strip one trailing newline from the input (e.g. from `echo` or a text file)")
    parser.add_argument('-f', '--file'    , type=str           , help="File to load seed/source data from")
    parser.add_argument('-s', '--struct'  , action="store_true", help="Output any hashes as C++ `struct sha256state` instances")
    parser.add_argument('-a', '--attempts', type=int           , help="Number of hash datas to generate from the seed data")
    parser.add_argument('-z', '--zeroes'  , type=int           , help="Number of zeros to search for during solving")
    parser.add_argument('-p', '--processes',type=int           , help="Number of processes to use for solving for hashes starting with zeroes")

    parser.add_argument('-H', '--hash'    , action="store_true", help="Hash the input data")
    parser.add_argument('-c', '--seed'    , action="store_true", help="Use the input data as seed data for hash data generation")
    parser.add_argument('-b', '--bits'    , action="store_true", help="Solve for a number of zero bits")
    parser.add_argument("-n", '--nibbles' , action="store_true", help="Solve for a number of zero nibbles")


    args = parser.parse_args()

    mode_flags = (args.hash, args.seed, args.bits, args.nibbles)
    match mode_flags:
        case (True, False, False, False):
            print(do_hashing(load_input(args.file, args.file is not None), args.struct))
        case (False, True, False, False):
            print(do_hashgen(load_input(args.file, args.file is not None), args.attempts))
        case (False, True, True, False):
            print(do_solving(load_input(args.file, args.file is not None), args.attempts, args.zeroes, args.processes, args.struct))
        case (False, True, False, True):
            print(do_solving(load_input(args.file, args.file is not None), args.attempts, args.zeroes * 4, args.processes, args.struct))
        case _:
            print("Selection of mode flags is not compatible")