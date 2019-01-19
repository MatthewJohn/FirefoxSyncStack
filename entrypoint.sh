#!/bin/bash

# If settings file does not exist,
# perform initial config
if [ ! -f "/settings_include.sh" ]
then
  /setup.sh
fi

/start_all.sh
