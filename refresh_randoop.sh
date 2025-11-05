#!/usr/bin/env bash

source BashUtils/utils.sh
DEBUG=1

RANDOOP_DIR="framework/lib/test_generation/generation/randoop-4.2.5"
INIT_SCRIPT="./init.sh"

if [ -d "$RANDOOP_DIR" ]; then
	debug "Randoop directory exists"
else
	error "Randoop directory does not exist" 100
fi

if [ -f "$INIT_SCRIPT" ]; then
	debug "$INIT_SCRIPT exists"
else
	error "$INIT_SCRIPT does not exist" 101
fi

if [ -x "$INIT_SCRIPT" ]; then
	debug "$INIT_SCRIPT has execution permissions"
else
	error "$INIT_SCRIPT has execution permissions" 101
fi

infoMessage "Removing $RANDOOP_DIR..."
rm -rf "$RANDOOP_DIR"
infoMessage "removed"

infoMessage "Running $INIT_SCRIPT..."
$INIT_SCRIPT
infoMessage "done"
