#!/bin/bash 


if [ $# -lt 8 ]
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

noise=$8

bpeOperationsAux=$9
bpath=${10}
maxLegthAfterBpe=100


if [ $noise == "rev" -o $noise == "src" ]; then
	bpeOperationsAux="none"
	bpath="none"
fi


if [ $noise == "wrdp" -o $noise == "swap" ]; then
        bpath="none"
fi

set -euo pipefail


#source train-steps-tensorflow.sh
source train-steps-fairseq-transformer-base.sh
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

add_task $noise $bpeOperationsAux $bpath train tc train2
apply_bpe train2 tc $lang1
if [ "$noise" != "bpe" ] && [ "$noise" != "rev2" ]
then
  apply_bpe train2 tc $lang2
fi

clean_corpus train2 bpe clean-bpe

prepare_dev_test_sets

make_data_for_training train train2


train_nmt

translate_test train
debpe_detruecase_detok_test train
report train

make_data_for_tuning train
tune_nmt

translate_test tune
debpe_detruecase_detok_test tune
report tune

clean
