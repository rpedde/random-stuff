#!/usr/bin/env python

import getopt
import gzip
import sys
import os
import struct

class PSFFile(object):
    def __init__(self, filename):
        self.filename = filename
        self.bitmap_data=[]
        self.load_font()

    def load_font(self):
        fh = gzip.GzipFile(self.filename, 'r')

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

        pad_size = 1
        while(pad_size < self.fontheight):
            pad_size *= 2

        self.padding = pad_size - self.fontheight
        print 'Padding: %d' % self.padding


    def dump_file(self, filename, padding=False, mif=False):
        f = open(filename, 'w')
        for x in range(0, 256):
            if mif:
                for data in self.bitmap_data[x]:
                    f.write(to_bin(data) + '\n')
            else:
                f.write(''.join([chr(i) for i in self.bitmap_data[x]]))

            if padding:
                for _ in range(0, self.padding):
                    if mif:
                        f.write('00000000\n')
                    else:
                        f.write(chr(0))
        f.close()

def to_bin(i):
    str_return = ''
    while i:
        if i & 1:
            str_return = '1' + str_return
        else:
            str_return = '0' + str_return
        i = i >> 1

    return ('00000000' + str_return)[-8:]

def usage_quit():
    print "Usage: dumpfont <options>\n"
    print "Options:"
    print " -i <infile>    input filename"
    print " -o <outfile>   output filename"
    print " -p             pad to even power of 2"
    print " -m             output in mif format instead of binary"
    sys.exit(1)


def main():
    in_file = None
    out_file = None
    pad = False
    mif = False

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'i:o:pm')
    except getopt.GetoptError, err:
        print str(err)
        usage_quit()


    for o, a in opts:
        if o == '-i':
            in_file = a
        elif o == '-o':
            out_file = a
        elif o == '-p':
            pad = True
        elif o == '-m':
            mif = True
        else:
            print 'Unknown option: %s' % o
            usage_quit()

    if in_file is None or out_file is None:
        print "Input and output file name is required\n"
        usage_quit()

    font = PSFFile(in_file)
    font.info()
    font.dump_char('A')
    font.dump_file(out_file, pad, mif)

main()
