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
import struct
import zlib

def get_file_type_id(file_type_name):
    return (zlib.crc32(file_type_name) ^ 0xffffffff) & 0x7fffffff

def create_archive(exploit_path, archive_path, jpn=True, quest_id=1010001):
    # create quest file
    quest = struct.pack('fI4xI296x', 200.6, 1, quest_id)
    resource = struct.pack('I64s',
            get_file_type_id(b'rTexture'),
            b'quest\\questData\\exploit')
    quest += resource * 15
    if not jpn:
        quest += resource * 4
    quest += b'\x00\x00\x00\x00'
    #setup info for adding exploit file to archive
    exploit_data_offset = 2 * 0x50 + 12
    exploit = open(exploit_path, 'rb').read()
    exploit_size = len(exploit) | 0x40000000
    exploit = zlib.compress(exploit)
    exploit_info = struct.pack('64s4I',
            b'quest\\questData\\exploit',
            get_file_type_id(b'rTexture'),
            len(exploit),
            exploit_size,
            exploit_data_offset)
    # setup info for adding quest file to archive
    quest_data_offset = exploit_data_offset + len(exploit)
    quest_size = len(quest) | 0x40000000
    quest = zlib.compress(quest)
    quest_info = struct.pack('64s4I',
            'quest\\questData\\questData_{}'.format(quest_id).encode(),
            get_file_type_id(b'rQuestData'),
            len(quest),
            quest_size,
            quest_data_offset)
    # create archive file
    archive = open(archive_path, 'wb')
    archive.write(struct.pack('4sHHI', b'ARC', 0x11, 2, 0))
    archive.write(exploit_info)
    archive.write(quest_info)
    archive.write(exploit)
    archive.write(quest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Creates a quest archive with the given exploit file.')
    parser.add_argument('region', choices=['JPN', 'EUR', 'USA'], help='quest format region')
    parser.add_argument('exploit_file', help='exploit TEX input file')
    parser.add_argument('archive_file', help='quest ARC output file')
    parser.add_argument('-q', '--quest_id', type=int, default=1010001, help='set the ID of the quest')
    args = parser.parse_args()
    create_archive(args.exploit_file, args.archive_file, args.region == 'JPN', args.quest_id)

