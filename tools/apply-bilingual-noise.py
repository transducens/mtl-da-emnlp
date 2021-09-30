import sys
import random

def get_target_vocab_from_prob_dic(prob_dic_reader):
    target_vocab=set()
    for line in prob_dic_reader:
        tgt_tok,src_tok,prob_str = line.strip().split()
        target_vocab.add(tgt_tok)
    return target_vocab

def read_prob_dic(prob_dic_reader):
    prob_dic={}
    for line in prob_dic_reader:
        tgt_tok,src_tok,prob_str = line.strip().split()
        if tgt_tok != "NULL" and src_tok!="NULL":
            if src_tok not in prob_dic:
                prob_dic[src_tok] = {}
            prob_dic[src_tok][tgt_tok] = float(prob_str)

    biling_lexicon={}
    for src_tok, tgt_map in prob_dic.items():
        biling_lexicon[src_tok]=max(tgt_map, key=tgt_map.get)

    return biling_lexicon

def target_word_replacement(stoks, ttoks, proportion, tgt_vocab):
    n_words_replace=int(len(ttoks)*proportion)
    tgt_positions =  random.sample(range(len(ttoks)), n_words_replace)
    vocab_list = list(tgt_vocab)
    vocab_positions = random.sample(range(len(vocab_list)), n_words_replace)
    for tgt_pos,vocab_pos in zip(tgt_positions,vocab_positions):
        ttoks[tgt_pos]=vocab_list[vocab_pos]
    return stoks,ttoks,False

def biword_replacement(stoks, ttoks, proportion, algs, biling_lexicon):
    n_words_replace=int(len(ttoks)*proportion)
    if n_words_replace < len(algs):
        alg_positions = random.sample(range(len(algs)), n_words_replace)
        more_words_than_alg = False
    else:
        more_words_than_alg = True
        #sys.stderr.write("WARNING: segment pair ('"+" ".join(stoks)+"', '"+" ".join(ttoks)+"') has less alignments ("+str(len(algs))+") than the expected number of words to be replaced ("+str(n_words_replace)+")\n")
        alg_positions = range(len(algs))
    lexicon_list = biling_lexicon
    #lexicon_list = list(biling_lexicon.items())
    lexicon_positions = random.sample(range(len(lexicon_list)), n_words_replace)
    for alg_pos,lex_pos in zip(alg_positions,lexicon_positions):
        s_alg,t_alg = algs[alg_pos]
        #t_alg=algs[alg_pos][1]
        s_tok_repl,t_tok_repl = lexicon_list[lex_pos]

        stoks[s_alg]=s_tok_repl
        ttoks[t_alg]=t_tok_repl

    return stoks,ttoks,more_words_than_alg

def apply_noise(stoks,ttoks,t,arg=None,alignments=None,lexicon=None):
    #Default is rev
    if t == "replace":
        return biword_replacement(stoks, ttoks, float(arg), alignments, lexicon)
    elif t == "replace_tgt":
        return target_word_replacement(stoks, ttoks, float(arg), lexicon)
    else: # error
        exit(1)

type=sys.argv[1]
if len(sys.argv)>=3:
    arg=sys.argv[2]
    if len(sys.argv)>=5:
        alg=sys.argv[3]
        alg_reader=open(alg,"r")
        prob_dic=sys.argv[4]
        with open(prob_dic,"r") as prob_dic_reader:
            if type == "replace":
                #lexicon = read_prob_dic(prob_dic_reader)
                lexicon = list(read_prob_dic(prob_dic_reader).items())
            else:
                lexicon = get_target_vocab_from_prob_dic(prob_dic_reader)
    else:
        alg=None
        prob_dic=None
else:
    arg=None
    alg=None
    prob_dic=None

more_words_than_alg_count=0
for line in sys.stdin:
    line=line.rstrip("\n")
    lines=line.split("\t")
    stoks=lines[0].split()
    ttoks=lines[1].split()
    alignments = []
    alignment_str = alg_reader.readline().split()
    for algtok in alignment_str:
        field1,field2=algtok.split("-")
        alignments.append((int(field1),int(field2)))

    if type != "none":
        stoks,ttoks,more_words_than_alg = apply_noise(stoks,ttoks,type,arg,alignments,lexicon)
        if more_words_than_alg:
            more_words_than_alg_count += 1
        print(" ".join(stoks)+"\t"+" ".join(ttoks))
if more_words_than_alg_count > 0:
    sys.stderr.write("WARNING: Found "+str(more_words_than_alg_count)+" instances with not enough alignments to cover the proportion of words to be replaced\n")
