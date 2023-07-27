#!/usr/bin/bash

# Simple documentation generator
# relies on words being documented inline with comments starting with #:, then this script simply extracts and dumps into a markdown file

fgrep  "#:" src/*
