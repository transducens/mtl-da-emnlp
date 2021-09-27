#!/bin/bash

export MTLDA_MOSES
export MTLDA_MGIZAPP

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
maxLegthAfterBpe=100


if [ $noise == "rev" -o $noise == "src" ]; then
	bpeOperationsAux="none"
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

NUMAUX=2
MAKE_DATA_INPUT="train "
for localnoise in $(echo "$noise" | tr '+' '\n') ; do

  add_task $localnoise $bpeOperationsAux train tc train$NUMAUX
  apply_bpe train$NUMAUX tc $lang1

  if [ "$localnoise" != "bpe" ] && [ "$localnoise" != "rev2" ]
  then
    apply_bpe train$NUMAUX tc $lang2
  fi

  clean_corpus train$NUMAUX bpe clean-bpe

  MAKE_DATA_INPUT="$MAKE_DATA_INPUT train$NUMAUX"

  NUMAUX=$(expr $NUMAUX + 1)

done

prepare_dev_test_sets

make_data_for_training $MAKE_DATA_INPUT

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
