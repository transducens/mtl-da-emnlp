#!/bin/bash

MYFULLPATH="$(readlink -f $0)"
CURDIR="$(dirname $MYFULLPATH)"

set -euo pipefail

# Variables to be set in the file
# lang1=$1
# lang2=$2
# permanentDir=$3
# bpeOperations=$4
# trainCorpus=$5
# devCorpus=$6
# testCorpus=$7
# noise=$8
# bpOperationsAux=$9

gpuId=0
temp=/tmp
#trainArgs="--arch transformer --encoder-layers 5 --decoder-layers 5  --encoder-embed-dim 512 --decoder-embed-dim 512 --encoder-ffn-embed-dim 2048 --decoder-ffn-embed-dim 2048  --encoder-attention-heads 2 --decoder-attention-heads 2 --encoder-normalize-before --decoder-normalize-before --dropout 0.4 --attention-dropout 0.2 --relu-dropout 0.2 --weight-decay 0.0001 --label-smoothing 0.2 --criterion label_smoothed_cross_entropy  --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0 --lr-scheduler inverse_sqrt --warmup-updates 4000 --warmup-init-lr 1e-7 --lr 1e-3 --min-lr 1e-9  --save-interval-updates 1000  --patience 10 --no-progress-bar --max-tokens 4000 --eval-bleu --eval-tokenized-bleu --eval-bleu-args '{\"beam\":5,\"max_len_a\":1.2,\"max_len_b\":10}' --best-checkpoint-metric bleu --maximize-best-checkpoint-metric --keep-best-checkpoints 1 --keep-interval-updates 1 --no-epoch-checkpoints"


#trainArgs="--arch transformer_wmt_en_de --share-all-embeddings  --label-smoothing 0.1 --criterion label_smoothed_cross_entropy --weight-decay 0  --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0 --lr-scheduler inverse_sqrt --warmup-updates 8000 --warmup-init-lr 1e-7 --lr 0.0007 --min-lr 1e-9  --save-interval-updates 1000  --patience 6 --no-progress-bar --max-tokens 4000 --eval-bleu --eval-tokenized-bleu --eval-bleu-args '{\"beam\":5,\"max_len_a\":1.2,\"max_len_b\":10}' --best-checkpoint-metric bleu --maximize-best-checkpoint-metric --keep-best-checkpoints 1 --keep-interval-updates 1 --no-epoch-checkpoints"
##Descomentar per a executar WMT
trainArgs="--arch transformer_wmt_en_de --share-all-embeddings  --label-smoothing 0.1 --criterion label_smoothed_cross_entropy --weight-decay 0  --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0 --lr-scheduler inverse_sqrt --warmup-updates 8000 --warmup-init-lr 1e-7 --lr 0.0007 --min-lr 1e-9  --save-interval-updates 5000  --patience 6 --no-progress-bar --max-tokens 4000 --eval-bleu --eval-tokenized-bleu --eval-bleu-args '{\"beam\":5,\"max_len_a\":1.2,\"max_len_b\":10}' --best-checkpoint-metric bleu --maximize-best-checkpoint-metric --keep-best-checkpoints 1 --keep-interval-updates 1 --no-epoch-checkpoints"

moses_scripts=$CURDIR/submodules/moses-scripts/scripts/

nomalizer=$moses_scripts/tokenizer/normalize-punctuation.perl
tokenizer=$moses_scripts/tokenizer/tokenizer.perl
detokenizer=$moses_scripts/tokenizer/detokenizer.perl
clean_corpus=$moses_scripts/training/clean-corpus-n.perl
train_truecaser=$moses_scripts/recaser/train-truecaser.perl
truecaser=$moses_scripts/recaser/truecase.perl
detruecaser=$moses_scripts/recaser/detruecase.perl

apply_noise="python $CURDIR/tools/apply-noise.py"
apply_bil_noise="python $CURDIR/tools/apply-bilingual-noise.py"

prepare_data () {

  prefix=$1  # Prefix to corpus
  tag=$2 #train / dev / test

  echo "prepare_data $prefix $tag ######################"

  if [ ! -e $prefix.$lang1 ]
  then
    echo "prepare_data: ERROR: File $prefix.$lang1 does not exist"
    exit 1
  fi

    if [ ! -e $prefix.$lang2 ]
  then
    echo "prepare_data: ERROR: File $prefix.$lang2 does not exist"
    exit 1
  fi

  mkdir -p $permanentDir/corpus
  cat $prefix.$lang1 > $permanentDir/corpus/$tag.$lang1
  cat $prefix.$lang2 > $permanentDir/corpus/$tag.$lang2
}

prepare_backtranslated_data () {

  prefix=$1  # Prefix to corpus
  tag=$2 #train / dev / test
  slbacktrans=$3
  tlbacktrans=$4

  echo "prepare_data $prefix $tag ######################"

  if [ ! -e $prefix.$lang1 ]
  then
    echo "prepare_data: ERROR: File $prefix.$lang1 does not exist"
    exit 1
  fi

    if [ ! -e $prefix.$lang2 ]
  then
    echo "prepare_data: ERROR: File $prefix.$lang2 does not exist"
    exit 1
  fi

  if [ ! -e $slbacktrans ]
  then
    echo "prepare_data: ERROR: File $slbacktrans does not exist"
    exit 1
  fi

  if [ ! -e $tlbacktrans ]
  then
    echo "prepare_data: ERROR: File $tlbacktrans does not exist"
    exit 1
  fi

  mkdir -p $permanentDir/corpus
  cat $prefix.$lang1 $slbacktrans > $permanentDir/corpus/$tag.$lang1
  cat $prefix.$lang2 $tlbacktrans > $permanentDir/corpus/$tag.$lang2
}


tokenize () {
  prefix=$1
  lang=$2

  echo "tokenize $prefix $lang ######################"

  if [ ! -e $permanentDir/corpus/$prefix.$lang ]
  then
    echo "tokenize: ERROR: File $permanentDir/corpus/$prefix.$lang does not exist"
    exit 1
  fi

  cat $permanentDir/corpus/$prefix.$lang | $nomalizer -l $lang | $tokenizer -a -no-escape -l $lang > $permanentDir/corpus/$prefix.tok.$lang
}

clean_corpus () {
  prefix=$1 # train / train2
  intag=$2  # tok / bpe
  outtag=$3 # clean / clean-bpe

  echo "clean_corpus $prefix $intag $outtag ######################"

  if [ ! -e $permanentDir/corpus/$prefix.$intag.$lang1 ]
  then
    echo "clean_corpus: ERROR: File $permanentDir/corpus/$prefix.$intag.$lang1 does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/$prefix.$intag.$lang2 ]
  then
    echo "clean_corpus: ERROR: File $permanentDir/corpus/$prefix.$intag.$lang2 does not exist"
    exit 1
  fi

  paste $permanentDir/corpus/$prefix.$intag.$lang1 $permanentDir/corpus/$prefix.$intag.$lang2 |\
  grep -v "http:" | grep -v "https:" | awk 'BEGIN{FS="[\t]"}{if ($1!=$2) print}' > $permanentDir/corpus/$prefix.$intag.preclean
  cut -f1 $permanentDir/corpus/$prefix.$intag.preclean > $permanentDir/corpus/$prefix.$intag.preclean.$lang1
  cut -f2 $permanentDir/corpus/$prefix.$intag.preclean > $permanentDir/corpus/$prefix.$intag.preclean.$lang2
  $clean_corpus $permanentDir/corpus/$prefix.$intag.preclean $lang1 $lang2  $permanentDir/corpus/$prefix.$outtag 5 100 $permanentDir/corpus/$prefix.$outtag.lines-retained
}

learn_truecaser_train () {
  lang=$1

  echo "learn_truecaser_train $lang ######################"

  if [ ! -e $permanentDir/corpus/train.clean.$lang ]
  then
    echo "learn_truecaser_train: ERROR: File $permanentDir/corpus/train.clean.$lang does not exist"
    exit 1
  fi

  mkdir -p $permanentDir/model/truecaser
  $train_truecaser -corpus $permanentDir/corpus/train.clean.$lang -model $permanentDir/model/truecaser/truecase-model.$lang
}

apply_truecaser () {
  prefix=$1
  intag=$2
  outtag=$3
  lang=$4

  echo "apply_truecaser $prefix $intag $outtag $lang ######################"

  if [ ! -e $permanentDir/corpus/$prefix.$intag.$lang ]
  then
    echo "apply_truecaser: ERROR: File $permanentDir/corpus/$prefix.$intag.$lang does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/model/truecaser/truecase-model.$lang ]
  then
    echo "apply_truecaser: ERROR: File $permanentDir/model/truecaser/truecase-model.$lang does not exist"
    exit 1
  fi

  cat $permanentDir/corpus/$prefix.$intag.$lang | $truecaser -model $permanentDir/model/truecaser/truecase-model.$lang > $permanentDir/corpus/$prefix.$outtag.$lang
}


learn_join_bpe () {
  operations=$1

  if [ $# -eq 2 ]
  then
    ttag=$2
  else
    ttag=""
  fi

  echo "learn_join_bpe $operations $ttag ######################"

  if [ ! -e $permanentDir/corpus/train.tc.$lang1 ]
  then
    echo "learn_join_bpe: ERROR: File $permanentDir/corpus/train.tc.$lang1 does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/train.tc.$lang2 ]
  then
    echo "learn_join_bpe: ERROR: File $permanentDir/corpus/train.tc.$lang2 does not exist"
    exit 1
  fi

  cat $permanentDir/corpus/train.tc.$lang1 | sed -re 's/\s+/ /g'  > $permanentDir/corpus/train.tc.$lang1.bpeready
  cat $permanentDir/corpus/train.tc.$lang2 | sed -re 's/\s+/ /g'  > $permanentDir/corpus/train.tc.$lang2.bpeready

  subword-nmt learn-joint-bpe-and-vocab --input $permanentDir/corpus/train.tc.$lang1.bpeready $permanentDir/corpus/train.tc.$lang2.bpeready \
              -s $operations -o $permanentDir/model/vocab.$lang1$lang2.bpe$ttag --write-vocabulary \
              $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang1 $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang2
}

apply_bpe () {
  prefix=$1
  label=$2
  lang=$3

  if [ $# -eq 4 ]
  then
    ttag=$4
  else
    ttag=""
  fi


  echo "apply_bpe $prefix $label $lang $ttag ######################"

  if [ ! -e $permanentDir/model/vocab.$lang1$lang2.bpe$ttag ]
  then
    echo "apply_bpe: ERROR: File $permanentDir/model/vocab.$lang1$lang2.bpe$ttag does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang1 ]
  then
    echo "apply_bpe: ERROR: File $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang1 does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang2 ]
  then
    echo "apply_bpe: ERROR: File $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang2 does not exist"
    exit 1
  fi

  cat $permanentDir/corpus/$prefix.$label.$lang |\
  subword-nmt apply-bpe --vocabulary $permanentDir/model/vocab.$lang1$lang2.bpe$ttag.bpevocab.$lang --vocabulary-threshold 1 \
                        -c $permanentDir/model/vocab.$lang1$lang2.bpe$ttag > $permanentDir/corpus/$prefix.bpe.$lang
}

add_task () {
  tasktype=$1
  bpeAux=$2
  bpath=$3
  prefix=$4
  label=$5
  tag=$6

  echo "add_task $tasktype $bpeAux $bpath $prefix $label $tag ######################"

  if [ ! -e $permanentDir/corpus/$prefix.$label.$lang1 ]
  then
    echo "add_task: ERROR: File $permanentDir/corpus/$prefix.$label.$lang1 does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/$prefix.$label.$lang2 ]
  then
    echo "add_task: ERROR: File $permanentDir/corpus/$prefix.$label.$lang2 does not exist"
    exit 1
  fi

  cat $permanentDir/corpus/$prefix.$label.$lang1  > $permanentDir/corpus/$tag.$label.$lang1

  if [ "$tasktype" = "src" ]
  then
    cat $permanentDir/corpus/$prefix.$label.$lang1  > $permanentDir/corpus/$tag.$label.$lang2
  elif [ "$tasktype" = "bpe" ]
  then
    learn_join_bpe $bpeAux Aux
    cat $permanentDir/corpus/$prefix.$label.$lang2  > $permanentDir/corpus/$tag.$label.$lang2
    apply_bpe $tag $label $lang2 Aux
  elif [ "$tasktype" = "rev2" ]
  then
    cat $permanentDir/corpus/$prefix.$label.$lang2 > $permanentDir/corpus/$tag.$label.$lang2
    apply_bpe $tag $label $lang2
    mv $permanentDir/corpus/$tag.bpe.$lang2 $permanentDir/corpus/$tag.bpe.before-rev2.$lang2
    cat $permanentDir/corpus/$tag.bpe.before-rev2.$lang2 | $apply_noise rev > $permanentDir/corpus/$tag.bpe.$lang2
  elif [ "$tasktype" = "mono" ]
  then
    cat $bpath/monotone.$lang1-$lang2.$lang1 > $permanentDir/corpus/$tag.$label.$lang1
    cat $bpath/monotone.$lang1-$lang2.$lang2 > $permanentDir/corpus/$tag.$label.$lang2
  elif [ "$tasktype" = "replace" ] || [ "$tasktype" = "replace_tgt" ]
  then

    #Call script to build alignments and lexicon
    bash $CURDIR/tools/build_alignments_and_lexicon.sh $lang1 $lang2 $permanentDir $permanentDir/lexicon "$(nproc)" "$MTLDA_MOSES" "$MTLDA_MGIZAPP"

    #corpora=$bpath/corpus.tok.truecase.clean
    #alignments=$bpath/aligned.intersection
    #bildic=$bpath/lex.f2e

    corpora=$permanentDir/lexicon/debpe.train
    alignments=$permanentDir/lexicon/intersection.alignments
    bildic=$permanentDir/lexicon/e2f.lexicon

    paste $corpora.$lang1 $corpora.$lang2 | $apply_bil_noise $tasktype $bpeAux $alignments $bildic > $permanentDir/corpus/$tag.$label.$lang1-$lang2 2> $permanentDir/corpus/log.replace
    cut -f1 $permanentDir/corpus/$tag.$label.$lang1-$lang2 > $permanentDir/corpus/$tag.$label.$lang1
    cut -f2 $permanentDir/corpus/$tag.$label.$lang1-$lang2 > $permanentDir/corpus/$tag.$label.$lang2
  else
    cat $permanentDir/corpus/$prefix.$label.$lang2 | $apply_noise $tasktype $bpeAux > $permanentDir/corpus/$tag.$label.$lang2
  fi
}

__add_to_tag () {
  input=$1
  output=$2
  totag=$3

  if [ ! -e $input ]
  then
    echo "__add_to_tag: ERROR: File $input does not exist"
  fi

  if [ "$noise" == "none" ]  || [ "$noise" == "" ]
  then
    sedcmd="cat -"
  else
    sedcmd="sed -re 's/^/TO_$totag /'"
  fi

  eval "$sedcmd < $input > $output"
}

make_data_for_training () {

  echo "make_data_for_training $@ ######################"

  rm -f $permanentDir/corpus/trainFinal.clean-bpe.$lang1
  rm -f $permanentDir/corpus/trainFinal.clean-bpe.$lang2
  #rm -fr $permanentDir/model/data-bin

  for tag in "$@"
  do
    if [ ! -e $permanentDir/corpus/$tag.clean-bpe.$lang1 ]
    then
      echo "make_data_for_training: ERROR: File $permanentDir/corpus/$tag.clean-bpe.$lang1 does not exist"
      exit 1
    fi

    if [ ! -e $permanentDir/corpus/$tag.clean-bpe.$lang2 ]
    then
      echo "make_data_for_training: ERROR: File $permanentDir/corpus/$tag.clean-bpe.$lang2 does not exist"
      exit 1
    fi

    if [ "$tag" = "train" ]
    then
      totag=$lang2
    else
      totag=$lang2$tag
    fi

    mv $permanentDir/corpus/$tag.clean-bpe.$lang1 $permanentDir/corpus/$tag.clean-bpe.before-to-tag.$lang1
    __add_to_tag $permanentDir/corpus/$tag.clean-bpe.before-to-tag.$lang1 $permanentDir/corpus/$tag.clean-bpe.$lang1 $totag

    cat $permanentDir/corpus/$tag.clean-bpe.$lang1 >> $permanentDir/corpus/trainFinal.clean-bpe.$lang1
    cat $permanentDir/corpus/$tag.clean-bpe.$lang2 >> $permanentDir/corpus/trainFinal.clean-bpe.$lang2
  done

  fairseq-preprocess -s $lang1 -t $lang2  --trainpref $permanentDir/corpus/trainFinal.clean-bpe \
                     --validpref $permanentDir/corpus/dev.bpe \
                     --destdir $permanentDir/model/data-bin-train --workers 16 --joined-dictionary
}

make_data_for_tuning () {

  echo "make_data_for_tuning $@ ######################"

  rm -f $permanentDir/corpus/tuneFinal.clean-bpe.$lang1
  rm -f $permanentDir/corpus/tuneFinal.clean-bpe.$lang2

  if [ ! -d $permanentDir/model/data-bin-train ]
  then
    echo "make_data_for_tuning: ERROR: Folder $permanentDir/model/data-bin-train does not exist"
    exit 1
  fi

  for tag in "$@"
  do
    if [ ! -e $permanentDir/corpus/$tag.clean-bpe.$lang1 ]
    then
      echo "make_data_for_tuning: ERROR: File $permanentDir/corpus/$tag.clean-bpe.$lang1 does not exist"
      exit 1
    fi

    if [ ! -e $permanentDir/corpus/$tag.clean-bpe.$lang2 ]
    then
      echo "make_data_for_tuning: ERROR: File $permanentDir/corpus/$tag.clean-bpe.$lang2 does not exist"
      exit 1
    fi

    if [ "$tag" = "train" ]
    then
      totag=$lang2
    else
      totag=$lang2$tag
    fi

    #mv $permanentDir/corpus/$tag.clean-bpe.$lang1 $permanentDir/corpus/$tag.clean-bpe.before-to-tag.$lang1
    #__add_to_tag $permanentDir/corpus/$tag.clean-bpe.before-to-tag.$lang1 $permanentDir/corpus/$tag.clean-bpe.$lang1 $totag

    cat $permanentDir/corpus/$tag.clean-bpe.$lang1 >> $permanentDir/corpus/tuneFinal.clean-bpe.$lang1
    cat $permanentDir/corpus/$tag.clean-bpe.$lang2 >> $permanentDir/corpus/tuneFinal.clean-bpe.$lang2
  done

  fairseq-preprocess -s $lang1 -t $lang2  --trainpref $permanentDir/corpus/tuneFinal.clean-bpe \
                     --srcdict $permanentDir/model/data-bin-train/dict.$lang1.txt \
                     --validpref $permanentDir/corpus/dev.bpe \
                     --destdir $permanentDir/model/data-bin-tune --workers 16 --joined-dictionary

                     ##--tgtdict $permanentDir/model/data-bin-train/dict.$lang2.txt
}

prepare_dev_test_sets () {

  echo "prepare_dev_test_sets ######################"

  if [ ! -e $permanentDir/corpus/dev.bpe.$lang1 ]
  then
    echo "prepare_dev_test_sets: ERROR: File $permanentDir/corpus/dev.bpe.$lang1 does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/test.bpe.$lang1 ]
  then
    echo "prepare_dev_test_sets: ERROR: File $permanentDir/corpus/test.bpe.$lang1 does not exist"
    exit 1
  fi


  mv $permanentDir/corpus/dev.bpe.$lang1 $permanentDir/corpus/dev.bpe.before_to_tag.$lang1
  __add_to_tag $permanentDir/corpus/dev.bpe.before_to_tag.$lang1 $permanentDir/corpus/dev.bpe.$lang1 $lang2

  mv $permanentDir/corpus/test.bpe.$lang1 $permanentDir/corpus/test.bpe.before_to_tag.$lang1
  __add_to_tag $permanentDir/corpus/test.bpe.before_to_tag.$lang1 $permanentDir/corpus/test.bpe.$lang1 $lang2
}

train_nmt () {
  echo "train_nmt ######################"

  if [ ! -d $permanentDir/model/data-bin-train ]
  then
    echo "train_nmt_fairseq: ERROR: Folder $permanentDir/model/data-bin-train does not exist"
    exit 1
  fi

  echo "Training args: $trainArgs"
  echo "See $permanentDir/model/train.log for details"

  eval "CUDA_VISIBLE_DEVICES=0 fairseq-train $trainArgs --seed $RANDOM --save-dir $permanentDir/model/checkpoints $permanentDir/model/data-bin-train &> $permanentDir/model/train.log"

  mv $permanentDir/model/checkpoints/checkpoint_best.pt $permanentDir/model/checkpoints/train.checkpoint_best.pt
  rm -fr $permanentDir/model/checkpoints/checkpoint*
}


tune_nmt () {
  echo "tune_nmt ######################"

  if [ ! -d $permanentDir/model/data-bin-tune ]
  then
    echo "tune_nmt_fairseq: ERROR: Folder $permanentDir/model/data-bin-tune does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/model/checkpoints/train.checkpoint_best.pt ]
  then
    echo "tune_nmt_fairseq: ERROR: File $permanentDir/model/checkpoints/train.checkpoint_best.pt does not exist"
    exit 1
  fi

  echo "Tune args: $trainArgs"
  echo "See $permanentDir/model/tune.log for details"

  eval "CUDA_VISIBLE_DEVICES=0 fairseq-train $trainArgs --seed $RANDOM --save-dir $permanentDir/model/checkpoints $permanentDir/model/data-bin-tune --reset-dataloader --restore-file $permanentDir/model/checkpoints/train.checkpoint_best.pt &> $permanentDir/model/tune.log"

  mv $permanentDir/model/checkpoints/checkpoint_best.pt $permanentDir/model/checkpoints/tune.checkpoint_best.pt
  rm -fr $permanentDir/model/checkpoints/checkpoint*
}

translate_test () {
  tag=$1
  echo "translate_test $tag ######################"

  if [ ! -e $permanentDir/model/checkpoints/$tag.checkpoint_best.pt ]
  then
    echo "translate_test_fairseq: ERROR: File $permanentDir/model/checkpoints/$tag.checkpoint_best.pt does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/test.bpe.$lang1 ]
  then
    echo "translate_test_fairseq: ERROR: File $permanentDir/corpus/test.bpe.$lang1 does not exist"
    exit 1
  fi

  if [ ! -d $permanentDir/model/data-bin-$tag ]
  then
    echo "train_nmt_fairseq: ERROR: Folder $permanentDir/model/data-bin-$tag does not exist"
    exit 1
  fi

  mkdir -p $permanentDir/eval/

  CUDA_VISIBLE_DEVICES=0 fairseq-interactive  --input $permanentDir/corpus/test.bpe.$lang1 --path $permanentDir/model/checkpoints/$tag.checkpoint_best.pt \
                                              $permanentDir/model/data-bin-$tag | grep '^H-' | cut -f 3 > $permanentDir/eval/test.output-$tag
}

translate_mono () {
  tag=$1
  echo "translate_mono $tag ######################"

  if [ ! -e $permanentDir/model/checkpoints/$tag.checkpoint_best.pt ]
  then
    echo "translate_mono_fairseq: ERROR: File $permanentDir/model/checkpoints/$tag.checkpoint_best.pt does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/mono.bpe.$lang1 ]
  then
    echo "translate_mono_fairseq: ERROR: File $permanentDir/corpus/mono.bpe.$lang1 does not exist"
    exit 1
  fi

  if [ ! -d $permanentDir/model/data-bin-$tag ]
  then
    echo "train_nmt_fairseq: ERROR: Folder $permanentDir/model/data-bin-$tag does not exist"
    exit 1
  fi

  mkdir -p $permanentDir/eval/

  CUDA_VISIBLE_DEVICES=0 fairseq-interactive  --input $permanentDir/corpus/mono.bpe.$lang1 --path $permanentDir/model/checkpoints/$tag.checkpoint_best.pt \
                                              $permanentDir/model/data-bin-$tag | grep '^H-' | cut -f 3 > $permanentDir/eval/mono.output-$tag
}

debpe_detruecase_detok_test () {
  tag=$1
  echo "debpe_detruecase_detok_test $tag ######################"

  if [ ! -e $permanentDir/eval/test.output-$tag ]
  then
    echo "debpe_detruecase_detok_test: ERROR: File $permanentDir/eval/test.output-$tag does not exist"
    exit 1
  fi

  cat $permanentDir/eval/test.output-$tag | sed -r 's/(@@ )|(@@ ?$)//g' > $permanentDir/eval/test.output-$tag.debpe
  cat $permanentDir/eval/test.output-$tag.debpe |  $detruecaser > $permanentDir/eval/test.output-$tag.detruecased
  cat $permanentDir/eval/test.output-$tag.detruecased  | $detokenizer -l $lang2 > $permanentDir/eval/test.output-$tag.detokenized
}


debpe_detruecase_detok_mono () {
  tag=$1
  echo "debpe_detruecase_detok_mono $tag ######################"

  if [ ! -e $permanentDir/eval/mono.output-$tag ]
  then
    echo "debpe_detruecase_detok_mono: ERROR: File $permanentDir/eval/mono.output-$tag does not exist"
    exit 1
  fi

  cat $permanentDir/eval/mono.output-$tag | sed -r 's/(@@ )|(@@ ?$)//g' > $permanentDir/eval/mono.output-$tag.debpe
  cat $permanentDir/eval/mono.output-$tag.debpe |  $detruecaser > $permanentDir/eval/mono.output-$tag.detruecased
  cat $permanentDir/eval/mono.output-$tag.detruecased  | $detokenizer -l $lang2 > $permanentDir/eval/mono.output-$tag.detokenized
}

report () {
  tag=$1
  echo "report $tag ######################"

  if [ ! -e $permanentDir/eval/test.output-$tag.detokenized ]
  then
    echo "report: ERROR: File $permanentDir/eval/test.output-$tag.detokenized does not exist"
    exit 1
  fi

  if [ ! -e $permanentDir/corpus/test.$lang2 ]
  then
    echo "report: ERROR: File $permanentDir/corpus/test.$lang2 does not exist"
    exit 1
  fi

  cat $permanentDir/eval/test.output-$tag.detokenized | sacrebleu $permanentDir/corpus/test.$lang2 --width 3 -l $lang1-$lang2 --metrics bleu chrf  > $permanentDir/eval/report-$tag
}

clean () {
  echo "clean ######################"

  rm -f $permanentDir/corpus/train.*
  rm -f $permanentDir/corpus/train[0-9].*
  rm -f $permanentDir/corpus/dev.$lang1 $permanentDir/corpus/dev.$lang2 $permanentDir/corpus/dev.tok.* $permanentDir/corpus/dev.tc.*
  rm -f $permanentDir/corpus/test.$lang1 $permanentDir/corpus/test.$lang2 $permanentDir/corpus/test.tok.* $permanentDir/corpus/test.tc.*
  rm -f $permanentDir/corpus/*.before_to_tag.*
  xz $permanentDir/corpus/trainFinal.*
  if [ -e $permanentDir/corpus/tuneFinal.clean-bpe.$lang1 ]
  then
    xz $permanentDir/corpus/tuneFinal.*
  fi
  cd $permanentDir/model
  tar cvfJ data-bin-train.tar.xz data-bin-train
  rm -fr data-bin-train
  tar cvfJ data-bin-tune.tar.xz data-bin-tune
  rm -fr data-bin-tune
  cd -
}
