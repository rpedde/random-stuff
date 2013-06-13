#!/usr/bin/env python

import getopt
import sys

# math is too hard for me.  figuring the right clock multiples
# on the clock synthesizer requires too much thought.  So this helps
# out a bit.

def find_close_matches(f1, f2, accuracy=.005):
    results = []

    for mul in range(2, 33):
        for div in range(1, 33):
            out_freq = (f1 * mul) / float(div)
            diff = abs(out_freq - f2)

            if diff < (f2 * accuracy):
                results.append((mul, div, out_freq, diff * 100 / f2))

    return results


def usage_quit():
    print "Usage: spartan-clock -i <in freq> -o <out freq> [-a <% accuracy>]"
    sys.exit(1)


def main():
    in_freq = None
    out_freq = None
    accuracy = .5  # expressed in percent

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'i:o:a:')
    except getopt.GetoptError, err:
        print str(err)
        usage_quit()

    for o, a in opts:
        if o == '-i':
            in_freq = float(a)
        elif o == '-o':
            out_freq = float(a)
        elif o == '-a':
            accuracy = float(a)
        else:
            print 'Unknown option: %s' % o
            usage_quit()

    if in_freq is None or out_freq is None:
        print 'input and output frequencies required'
        usage_quit()

    results = find_close_matches(in_freq, out_freq, accuracy / 100)

    if len(results) == 0:
        print 'No matches.  Sorry.  :('
    else:
        for tup in results:
            print "%d/%d: %.2f (%3.2f)" % tup


main()
