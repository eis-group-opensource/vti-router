#!/bin/bash
mkdir -p ~/scripts/WORK
rsync -av WORK/`hostname -s`.d ~/scripts/WORK/.
