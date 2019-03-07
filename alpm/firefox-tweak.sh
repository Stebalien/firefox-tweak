#!/bin/bash

set -e

while read target; do
    /usr/lib/firefox-tweak/tweak.sh "$target"
done
