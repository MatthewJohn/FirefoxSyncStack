#!/bin/bash

export PATH=$PATH:$HOME/.cargo/bin
source $HOME/.cargo/env

f_python_ssl() {
  apt-get install libssl1.0-dev node-gyp nodejs-dev npm --assume-yes
}
f_rust_ssl() {
  apt-get install libssl-dev --assume-yes
}

