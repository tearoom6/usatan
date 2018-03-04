# usatan

- Smart bot speaking Japanese.

## Setup

```sh
# Install dependencies.
$ brew install mecab
$ bundle

# Install mecab dictionary in local macOS.
$ wget https://osdn.net/dl/naist-jdic/mecab-naist-jdic-0.6.3b-20111013.tar.gz
$ tar zxfv mecab-naist-jdic-0.6.3b-20111013.tar.gz
$ cd mecab-naist-jdic-0.6.3b-20111013
$ ./configure --with-charset=utf8
$ make
$ sudo make install
$ cd ..

# Compile dictionary file for okura.
$ bundle exec okura compile /usr/local/lib/mecab/dic/naist-jdic naist-jdic
```

