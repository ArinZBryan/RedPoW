import sys
import argparse
import multiprocessing as mp
from pathlib import Path
import hashlib
from functools import partial
from math import floor

def do_seedgen(salt: str, phrase: str, strip: bool, unusual_lengths: bool):
    if strip == True:
        salt.removesuffix("\n")
        phrase.removesuffix("\n")

    if not unusual_lengths and len(phrase) != 32:
        raise ValueError("Phrase must be 32 characters")
    bincodedPhrase = phrase.encode('utf-8')
    bincodedLength = len(bincodedPhrase).to_bytes(8, 'little')
    prefix = b''.join([salt.encode('utf-8'), bincodedLength, bincodedPhrase])
    return prefix

def score(prefix: bytes, nonce: int):
    hasher = hashlib.sha256()
    hasher.update(prefix)
    hasher.update(str(nonce).encode("ascii"))
    hash = hasher.digest()
    return int.from_bytes(hash[0:16], 'big')

def check_nonce(seed_bytes: bytes, difficulty_factor: int, nonce: int):
    UINT128_MAX = 340282366920938463463374607431768211455
    target = UINT128_MAX - floor(UINT128_MAX / difficulty_factor)
    s = score(seed_bytes, nonce)
    if s >= target:
        return nonce, str(s)
    return None

def do_solving(seed: bytes, generate: int, goal: int, processes: int):
    with mp.Pool(processes=processes) as pool:
        results = pool.map(partial(check_nonce, seed, goal), range(1, generate + 1))
    
    successes = list(filter(lambda x: x != None, results))
    if len(successes) == 0:
        print(f"No solution with difficultyfactor {goal} found in {generate} nonces")

    for s in successes:
        if (s == None):
            # This should never trigger, since None's are filtered out,
            # but the typechecker doesn't seem to have realised this,
            # so this branch is here just to get the typechecker to chill out

            raise Exception("The filter didn't work")
        else:
            print(f"Successful Solution: nonce={s[0]}, score={s[1]}")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="RedPow CPU PoC",
        description="Implements some hashing functionality required for ReadPoW testing"
    )
     
    parser.add_argument('-s', '--salt'           , type=str           , help="Salt to use as input")
    parser.add_argument('-f', '--phrase'         , type=str           , help="Phrase to use as input")
    parser.add_argument('-t', '--strip'          , action="store_true", help="Strip one trailing newline from the input (e.g. from `echo` or a text file)")
    parser.add_argument('-a', '--attempts'       , type=int           , help="Number of hash datas to generate from the seed data")
    parser.add_argument('-d', '--difficulty'     , type=int           , help="Difficulty factor")
    parser.add_argument('-p', '--processes'      , type=int           , help="Number of processes to use for solving for hashes starting with zeroes")
    parser.add_argument('-u', '--unusual_lengths', action="store_true", help="Accept phrases that are not exactly 32 bytes long")

    args = parser.parse_args()

    do_solving(do_seedgen(args.salt, args.phrase, args.strip, args.unusual_lengths), args.attempts, args.difficulty, args.processes)