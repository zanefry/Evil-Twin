#!/usr/bin/env python3

import sys

def main():
    areacode_file, out_file = sys.argv[1:]

    area_codes = []
    with open(areacode_file) as code_list:
        area_codes = [l.rstrip() for l in code_list.readlines()]

    with open(out_file, 'w') as output:
        for code in area_codes:
            for i in range(10000000):
                print(f"{code}{i:07d}", file=output)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: phone_numbers.py <area code list> <output filename>")
    main()
