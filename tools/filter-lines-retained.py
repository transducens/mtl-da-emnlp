import sys
import argparse

parser = argparse.ArgumentParser(description="Filters a corpus based on the *.retained-lines file produced by Moses' clean-corpus-n.perl script. Reads file to be filtered form stdin and writes the result to stdout")
parser.add_argument('retained', help="*.retained-lines file")
args = parser.parse_args()


retained_fn=args.retained

with open(retained_fn) as retained_f:
    readRetained=retained_f.readline()

    lineno=0
    for line in sys.stdin:
        lineno+=1
        
        if readRetained == '':
            break
        curRetained=int(readRetained)

        if lineno == curRetained:
            print(line,end="")
            readRetained=retained_f.readline()

