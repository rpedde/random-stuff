#!/usr/bin/env python

import getopt
import sys

def main():
    outfile = infile = None
    offsets = {}

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'i:o:x:y:')
    except getopt.GetoptError, err:
        print str(err)
        sys.exit(1)

    for o, a in opts:
        if o == '-i':
            infile = a
        elif o == '-o':
            outfile = a
        elif o == '-x':
            offsets['X'] = a
        elif o == '-y':
            offsets['Y'] = a
        else:
            print 'unknown option: %s' % o
            sys.exit(1)

    if not (infile and outfile and 'X' in offsets and 'Y' in offsets):
        print 'missing param infile, outfile, x, y'
        sys.exit(1)

    infd = open(infile, 'r')
    outfd = open(outfile, 'w')

    for line in infd:
        line = line.strip()
        tokens = line.split()

        for index in range(0,len(tokens)):
            if tokens[index].startswith('X') or tokens[index].startswith('Y'):
                oldval = str(float(tokens[index][1:]))
                newval = str(float(tokens[index][1:]) + float(offsets[tokens[index][:1]]))
                tokens[index] = tokens[index][:1] + newval

        outfd.write(' '.join(tokens) + '\n')

    infd.close()
    outfd.close()

    print 'done'

if __name__ == '__main__':
    main()
