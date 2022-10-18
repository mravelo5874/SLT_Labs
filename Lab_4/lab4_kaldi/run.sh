\#!/usr/bin/env bash

data=/lusr/opt/kaldi/kaldi-master/egs/mini_librispeech/s5/corpus/
data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

stage=3
. utils/parse_options.sh

set -euo pipefail

if [ $stage -le 0 ]; then
  echo "[stage 0]"
  local/download_lm.sh $lm_url $data data/local/lm
fi

if [ $stage -le 1 ]; then
  echo "[stage 1]"
  # format the data as Kaldi data directories
  for part in dev-clean-2 train-clean-5; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
  done

  local/prepare_dict.sh --stage 3 --nj 30 --cmd "$train_cmd" \
    data/local/lm data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/format_lms.sh --src-dir data/lang_nosp data/local/lm
fi

if [ $stage -le 2 ]; then
  echo "[stage 2]"
  mfccdir=mfcc
  # extract MFCCs for train and test data
  steps/make_mfcc.sh data/train_clean_5 exp/make_mfcc $mfccdir
  steps/compute_cmvn_stats.sh data/train_clean_5
  
fi

# train a monophone system
if [ $stage -le 3 ]; then
  echo "[stage 3]"
  utils/subset_data_dir.sh --shortest data/train_clean_5 500 data/train_500short
  # train a monophone acoustic model
  steps/train_mono.sh --boost-silence 1.25 data/train_500short data/lang_nosp exp/mono
fi

# train a delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  echo "[stage 4]"
  # 1) force-align the entire training set with the monophone model
  steps/align_si.sh --boost-silence 1.25 data/train_clean_5 data/lang_nosp exp/mono exp/mono_ali_train_clean_5
  # 2) train the triphone model on the entire training set
  steps/train_deltas.sh 2000 100000 data/train_clean_5 data/lang_nosp exp/mono_ali_train_clean_5 exp/tri1
fi

if [ $stage -le 5 ]; then
  echo "[stage 5]"
  # TODO: 1) build the decoding graph
  # TODO: 2) decode using the triphone model
  # TODO: 3) rescore with the larger (tgmed) language model
fi
