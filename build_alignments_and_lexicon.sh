#! /bin/bash

lang1=$1
lang2=$2
corpusDir=$3
permanentDir=$4
njobs=$5
curdir=$(realpath $(dirname $0))

#Taking pre-processed training data and reverting BPE
mkdir -p $permanentDir
cat $corpusDir/corpus/trainFinal.clean-bpe.$lang1  | sed -r 's/(@@ )|(@@ ?$)//g' > $permanentDir/debpe.train.$lang1
cat $corpusDir/corpus/trainFinal.clean-bpe.$lang2  | sed -r 's/(@@ )|(@@ ?$)//g' > $permanentDir/debpe.train.$lang2

#Running Moses word alignment (MGIZA++) to obtain word-alignments and a probabilistic lexicon
$curdir/submodules/mosesdecoder/scripts/training/train-model.perl  --alignment intersection --root-dir $permanentDir/mgizaoutput --corpus $permanentDir/debpe.train -e $lang2  -f $lang1 --mgiza --mgiza-cpus=$njobs --parallel --first-step 1 --last-step 4 --external-bin-dir $curdir/submodules/mgiza/mgizapp/build/bin/ --sort-compress gzip

#Extracting most-likely entries from lexicon, and building monolingual version of the bilingual lexicon
cat $permanentDir/mgizaoutput/model/lex.e2f  | python $curdir/build_lexicon.py > $permanentDir/e2f.lexicon
cut -f 1 $permanentDir/e2f.lexicon > $permanentDir/lexicon.$lang1
cut -f 2 $permanentDir/e2f.lexicon > $permanentDir/lexicon.$lang2

#Applying BPE to the monolingual lexicons
cat $permanentDir/lexicon.$lang1 | subword-nmt apply-bpe --vocabulary $corpusDir/model/vocab.${lang1}${lang2}.bpe.bpevocab.$lang1 --vocabulary-threshold 1 -c $corpusDir/model/vocab.${lang1}${lang2}.bpe > $permanentDir/lexicon.bpe.$lang1
cat $permanentDir/lexicon.$lang2 | subword-nmt apply-bpe --vocabulary $corpusDir/model/vocab.${lang1}${lang2}.bpe.bpevocab.$lang2 --vocabulary-threshold 1 -c $corpusDir/model/vocab.${lang1}${lang2}.bpe > $permanentDir/lexicon.bpe.$lang2

#Merging the non-BPE and BPE monolingual lexicons to obtain a bilingual lexicon in the form of a TSV file with four fields (two for non BPE and two more for BPE)
paste $permanentDir/lexicon.$lang1 $permanentDir/lexicon.$lang2 $permanentDir/lexicon.bpe.$lang1 $permanentDir/lexicon.bpe.$lang2 > $permanentDir/full.lexicon
#Moving the symmetrised alignments to the output directory
mv $permanentDir/mgizaoutput/model/aligned.intersection $permanentDir/intersection.alignments

