#!/bin/bash 

set -euo pipefail

if [ $# -lt 7 ]
then
  echo "Wrong number of arguments"
  exit 1
fi

lang1=$1
lang2=$2
permanentDir=$3
bpeOperations=$4

trainCorpus=$5
devCorpus=$6
testCorpus=$7

maxLegthAfterBpe=100
noise="none"

source train-steps-fairseq-transformer-base.sh
#source train-steps-tensorflow.sh
#########################################
prepare_data $trainCorpus train
prepare_data $testCorpus test
prepare_data $devCorpus dev

tokenize train $lang1
tokenize train $lang2

tokenize test $lang1
tokenize test $lang2

tokenize dev $lang1
tokenize dev $lang2

clean_corpus train tok clean

learn_truecaser_train $lang1
learn_truecaser_train $lang2

apply_truecaser train clean tc $lang1
apply_truecaser train clean tc $lang2

apply_truecaser dev tok tc $lang1
apply_truecaser dev tok tc $lang2

apply_truecaser test tok tc $lang1
apply_truecaser test tok tc $lang2

learn_join_bpe $bpeOperations

apply_bpe train tc $lang1
apply_bpe train tc $lang2

apply_bpe dev tc $lang1
apply_bpe dev tc $lang2

apply_bpe test tc $lang1
apply_bpe test tc $lang2

clean_corpus train bpe clean-bpe

prepare_dev_test_sets

make_data_for_training train
train_nmt

translate_test train
debpe_detruecase_detok_test train
report train

clean
