#!/usr/bin/env python

import gzip
import sys
import os
import struct

filename=sys.argv[1]

print 'opening %s' % filename

class PSFFile(object):
    def __init__(self, filename):
        self.filename = filename
        self.bitmap_data=[]
        self.load_font()

    def load_font(self):
        fh = gzip.GzipFile(filename, 'r')

        header_format = "cccc"

        input_bytes = fh.read(struct.calcsize(header_format))

        magic1, magic2, filemode, fontheight = struct.unpack(
            header_format, input_bytes)

        if magic1 != '\x36' and magic2 != '\x04':
            raise ValueError('not a psf file')

        self.fontheight = ord(fontheight)
        self.filemode = ord(filemode)

        # read the non-unicode data
        for x in range(0, 256):
            font_data = fh.read(self.fontheight)
            self.bitmap_data.append([ord(x) for x in font_data])

        fh.close()

    def dump_char(self, char):
        index = ord(char)
        for x in self.bitmap_data[index]:
            out = ''
            for y in range(0, 8):
                out = [' ', '*'][x & 1] + out
                x >>= 1

            print out

    def info(self):
        modes = [
            '256 characters, no unicode',
            '512 characters, no unicode',
            '256 characters, with unicode',
            '512 characters, with unicode']

        print 'Font height: %d' % self.fontheight
        print 'Mode: %02x (%s)' % (
            self.filemode, modes[self.filemode])

    def dump_file(self, filename):
        f = open(filename, 'w')
        for x in range(0, 256):
            f.write(''.join([chr(i) for i in self.bitmap_data[x]]))
        f.close()



font = PSFFile(filename)
font.info()
font.dump_char('A')
font.dump_file('out.fon')
