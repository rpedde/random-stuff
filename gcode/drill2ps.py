#!/usr/bin/env python

# turn a gcode drill file into a postscript file

import getopt
import os
import re
import sys

def main():
    drill_size = 0

    if len(sys.argv) != 2:
        print "usage: drill2ps.py <drill.nc>"
        sys.exit(1)

    infile = sys.argv[1]
    outfile = '.'.join([infile.rsplit('.',1)[0], 'ps'])

    print 'converting %s to %s' % (infile, outfile)

    infd = open(infile, 'r')
    outfd = open(outfile, 'w')

    outfd.write('/inch {72 mul} def\n')
    outfd.write('/doline {newpath 4 2 roll moveto lineto closepath stroke} def\n')
    outfd.write('/docircle {newpath 2 div 0 360 arc closepath stroke} def\n')

    outfd.write('4.25 inch 5.5 inch translate\n')
    outfd.write('-.1 inch 0 .1 inch 0 doline\n')
    outfd.write('0 -.1 inch 0 .1 inch doline\n')

    for line in infd:
        line = line.strip()
        match = re.match(r'.*drill size ([0-9.]+) inch.*', line)

        if match:
            drill_size = match.group(1)
        else:
            tokens = line.split()

            if tokens and (tokens[0] == 'G81' or tokens[0].startswith('X')):
                # this is a drill hole
                x = None
                y = None

                for token in tokens:
                    if token.startswith('X'):
                        x = token[1:]
                    if token.startswith('Y'):
                        y = token[1:]
                if not x or not y:
                    print 'oops: cannot parse "%s"' % line
                    sys.exit(1)

                outfd.write('%s inch %s inch %s inch docircle\n' % (x, y, drill_size))

    outfd.write('showpage\n')

    infd.close()
    outfd.close()

    print 'done'

if __name__ == '__main__':
    main()
