import sys
import random

def word_dropout(toks, proportion):
    n_words_dropout=int(len(toks)*proportion)
    word_positions = random.sample(range(len(toks)), n_words_dropout)
    #sys.stderr.write(str(word_positions)+"\n")
    for pos in word_positions:
        toks[pos]="★"
    return toks

def word_swap(toks, proportion):
    moved_pos=set()
    n_words_swap=int(len(toks)*proportion)
    #sys.stderr.write(str(toks)+"\n")
    while(len(moved_pos)<n_words_swap):
        pos1, pos2 = random.sample(range(len(toks)), 2)
        toks[pos1], toks[pos2] = toks[pos2], toks[pos1]
        moved_pos.add(pos1)
        moved_pos.add(pos2)
    #sys.stderr.write(str(moved_pos)+"\n")
    return toks

def apply_noise(toks,t,arg=None):
    #Default is rev
    if t == "shuf":
        return random.sample(toks,len(toks))
    elif t == "alpha":
        return sorted(toks)
    elif t == "invalpha":
        return sorted(toks, reverse=True)
    elif t == "length":
        return sorted(toks, key=len)
    elif t == "invlength":
        return sorted(toks, key=len, reverse=True)
    elif t == "copy":
        return toks
    elif t == "rev":  # reverse order before BPE
        return toks[::-1]
    elif t == "wrdp": # word dropout
        return word_dropout(toks, float(arg))
    elif t == "swap":
        return word_swap(toks, float(arg))
    else: # error
        exit(1)

type=sys.argv[1]
if len(sys.argv)>=3:
    arg=sys.argv[2]
else:
    arg=None

for line in sys.stdin:
    line=line.rstrip("\n")
    toks=line.split()
    if type != "none":
        print(" ".join(apply_noise(toks,type,arg)))
