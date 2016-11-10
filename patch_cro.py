'''
Copyright 2016 Seth VanHeulen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
'''

import argparse
import hashlib
import os
import struct

def patch_cro(cro_path, crr_hash_count):
    cro = open(cro_path, 'r+b')
    cro.seek(0xb0)
    text_start, text_size, data_start, data_size = struct.unpack('4I', cro.read(0x10))
    cro.seek(0x80)
    cro_hash_table = hashlib.sha256(cro.read(text_start - 0x80)).digest()
    cro_hash_table += hashlib.sha256(cro.read(text_size)).digest()
    cro_hash_table += hashlib.sha256(cro.read(data_start - text_start - text_size)).digest()
    cro_hash_table += hashlib.sha256(cro.read(data_size)).digest()
    cro.seek(0)
    cro.write(cro_hash_table)
    cro.seek(crr_hash_count * -0x20, os.SEEK_END)
    cro.write(hashlib.sha256(cro_hash_table).digest() * crr_hash_count)
    cro.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fixes the hashes in a CRO0 file header and adds a CRR0 hash table patch to the padding.')
    parser.add_argument('cro_file', help='CRO0 input file')
    parser.add_argument('hash_count', type=int, help='Number of hashes in CRR0 file')
    args = parser.parse_args()
    patch_cro(args.cro_file, args.hash_count)

