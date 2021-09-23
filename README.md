# MTL DA - EMNLP 2021
The repository contains the code needed to reproduce the experiments presented in the EMNLP 2021 paper "Rethinking data augmentation for low-resource neural machine translation: a multi-task learning approach".

## Set up environment and install software dependencies

Create a Python virtualenv and activate it:

```
virtualenv -p python3.6 ~/envs/mtl-da
source ~/envs/mtl-da/bin/activate
```

Clone and init submodules:
``` 
git clone https://github.com/transducens/mtl-da-emnlp.git
cd mtl-da-emnlp
git submodule update --init --recursive
```

Install dependencies:
```
pip install -r requirements.txt
```

## Download data

You can download all the corpora we used in our experiments as follows:

```
wget http://www.dlsi.ua.es/~vmsanchez/emnlp2021-data.tar.gz
tar xvzf emnlp2021-data.tar.gz
```

## Train baseline systems

In order to train a baseline system, run the script shown below, where the Bash variables have the following meaning:
* $L1 and $L2: source and target languages codes. Use `en` for English, `de` for German, `he` for Hebrew and `vi` for Vietnamese.
* $PAIR: language pair. We always consider English as the first language of the pair, regardless of whether it acts as the source of the target language. Possible values are `en-de`, `en-he`, and `en-vi`.
* $DIR: path to the directory that will be created during the training process and will contain files with the intermediate steps and results.
* $bpe: number of BPE merge operations. We used 10000 in all the experiments reported in the paper.
* $TRAINSET: training data to use. `iwslt` contains IWSLT training parallel data, while `iwsltbackt` also includes backtranslated monolingual English sentences extracted from TED Talks.

```
./train-baseline.sh $L1 $L2 $DIR $bpe data/$TRAINSET-$PAIR/train $DATA/$TRAINSET-$PAIR/dev $DATA/$TRAINSET-$PAIR/test
```

You can find the resulting BLEU and chrF++ scores in the file `$DIR/eval/report-train`


## Train systems with "reverse" or "source" auxiliary tasks

The Bash variables have the same meaning as in the previous section, and we have a new one:
* $AUXTASK: use `rev` for training with the "reverse" auxiliary task and `src` for training with the "source" auxiliary task.

```
./train-mtl1tasks.sh $L1 $L2 $DIR $bpe data/$TRAINSET-$PAIR/train $DATA/$TRAINSET-$PAIR/dev $DATA/$TRAINSET-$PAIR/test $AUXTASK
```

## Train systems with "token" or "swap" auxiliary tasks

The "token" and "swap" auxiliary tasks require an alpha parameter that controls the proportion of the sentence which is modified. This is the meaning of the Bash variables used in the script below:

* $AUXTASK: use `wrdp` for training with the "token" auxiliary task and `swap` for training with the "swap" auxiliary task.
* $ALPHA: proportion of the tokens in the target sentence that are modified. The best values are reported in the appendix of the paper.

```
./train-mtl1tasks.sh $L1 $L2 $DIR $bpe data/$TRAINSET-$PAIR/train $DATA/$TRAINSET-$PAIR/dev $DATA/$TRAINSET-$PAIR/test $AUXTASK $ALPHA
```

## Train systems with "mono" or "replace" auxiliary tasks

TODO
