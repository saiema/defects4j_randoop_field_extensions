#!/bin/bash

#Utility functions (debug, error, append, and appendPaths)
#These functions can be used for several scripts, take care about name clashing
#******************************************************************************
#Defined constants:
#DEBUG : used by debug function, although it can be used by user defined functions (it follows a C convention for boolean values)
#
#Defined functions:
#debug
#arguments: 1, the message to print
#it will print the message only if DEBUG is true (non 0 value)
#
#error
#arguments: 2, the message to print and a related error code (int)
#it will print the message and exit using the provided error code
#
#append
#arguments: 3 + Result, two strings and a separator, the last argument is a result (must be just a name, do not use $)
#if any of the strings is empty it will output the other one; otherwise it will result ${string1}${separator}${string2}
#
#appendPaths
#arguments: 3 + Result, two paths and a boolean stating if the path should end with a path separator, the last argument is a result (must be just a name, do not use $)
#similar to append but using `/` as a path separator

#set -x
DEBUG=0

COLOR_GREEN=$(tput setaf 2)
COLOR_BLUE=$(tput setaf 4)
COLOR_YELLOW=$(tput setaf 3)
COLOR_RED=$(tput setaf 1)
COLOR_NORMAL=$(tput sgr0)


#Prints message (in green)
#msg	: the message to print
function infoMessage() {
	infoMessageF "$1" 0
}

#Prints message (in green)
#msg	: the message to print
#raw    : print the message raw
function infoMessageF() {
	local msg="$1"
	local raw="$2"
	if [[ "$raw" -eq "0" ]]; then
	    printf "${COLOR_GREEN}INFO:$msg\n${COLOR_NORMAL}"
	else
	    printf "${COLOR_GREEN}INFO:%s\n${COLOR_NORMAL}" "$msg"
	fi
}

#Prints message (in blue) if DEBUG != 0
#msg	: the message to print
function debug() {
	debugF "$1" 0
}

#Prints message (in blue) if DEBUG != 0
#msg	: the message to print
#raw    : print the message raw
function debugF() {
	local msg="$1"
	local raw="$2"
	if [[ "$raw" -eq "0" ]]; then
	    [[ "$DEBUG" -ne "0" ]] && printf "${COLOR_BLUE}DEBUG:$msg\n${COLOR_NORMAL}"
	else
	    [[ "$DEBUG" -ne "0" ]] && printf "${COLOR_BLUE}DEBUG:%s\n${COLOR_NORMAL}" "$msg"
	fi
}

#Prints a warning message (in yellow)
function warning() {
	warningF "$1" 0
}

#Prints a warning message (in yellow)
#raw    : print the message raw
function warningF() {
	local msg="$1"
	local raw="$2"
	if [[ "$raw" -eq "0" ]]; then
	    printf "${COLOR_YELLOW}WARNING:$msg\n${COLOR_NORMAL}"
	else
	    printf "${COLOR_YELLOW}WARNING:%s\n${COLOR_NORMAL}" "$msg"
	fi
}

#Prints an error message (in red) and then exits with a provided exit code
#msg	   : the message to print
#ecode	   : the exit code
function error() {
	errorF "$1" "$2" 0
}

#Prints an error message (in red) and then exits with a provided exit code
#msg	   : the message to print
#ecode	   : the exit code
#raw    : print the message raw
function errorF() {
	local msg="$1"
	local ecode="$2"
	local raw="$3"
	if [[ "$raw" -eq "0" ]]; then
	    printf "${COLOR_RED}ERROR:$msg\n${COLOR_NORMAL}"
	else
	    printf "${COLOR_RED}ERROR:%s\n${COLOR_NORMAL}" "$msg"
	fi
	exit $ecode
}

#From a {key, value} config file, this function will return a string with all parsed configurations.
#This function can result in an error call 
#config file                    : The configuration file
#key,value separator            : Which symbol is used to relate keys with values (can't use or contain spaces)
#separator replacement          : What symbol to use as key, value separator in the resulting string (can be space)
#comment symbol                 : What symbol to use as comments, line starting with this symbol will be ignored (can't be or contains spaces)
#initial symbol or regex to use : A starting symbol or regex that defines what key,value pairs to extract (can't be or contains spaces)
#symbol to prepend in result    : A symbol to prepend for each parsed key, value pair in the result (can't be or contains spaces)
#result(R)                      : Where to store the result
function parseFromConfigFile() {
    local cfile="$1"
    local kvSep="$2"
    local kvSepRep="$3"
    local ignSym="$4"
    local stSymOrRgx="$5"
    local prependSym="$6"
    local result=""
    [ ! -e "$cfile" ] && error "Config file $cfile does not exist" 1
    [ -z "$kvSep" ] || $(echo "$kvSep" | egrep -q "[[:space:]]") && error "key,value separator is empty or contains spaces" 2
    [ -z "$ignSym" ] || $(echo "$ignSym" | egrep -q "[[:space:]]") && error "Comment symbol is empty or contains spaces" 3
    [ -z "$stSymOrRgx" ] || $(echo "$stSymOrRgx" | egrep -q "[[:space:]]") && error "Starting symbol or regex for key,value pairs to extract is empty or contains spaces" 4
    [ -z "$prependSym" ] || $(echo "$prependSym" | egrep -q "[[:space:]]") && error "key,value separator is empty or contains spaces" 5
    for keyVal in `grep -vE "^((${ignSym})|([[:space:]]))" ${cfile}`; do
        if echo "$keyVal" | grep -qE "^${stSymOrRgx}([[:graph:]])*${kvSep}([[:graph:]])+"; then
            newKeyValuePair=$(echo "$keyVal" | sed "s|${kvSep}|${kvSepRep}|g")
            append "$result" "${prependSym}${newKeyValuePair}" " " result
        fi
    done
    eval "$7='$result'"
}

#Given a file, a regular expression, and a not found value
#This function will return either the value associated with the regular expression, or the not found value
#Example: getValue "log" "Following this is the value \K[[:digit:]]+" "N/A" will return:
#       *   if log has a line with "Following this is the value 42", it will return 42
#       *   if not, it will return "N/A"
#Arguments
#ilogFile       : the log file where to look for expressions
#gexpt          : the regular expression to look
#notFoundValue  : the value to return when the regular expresion has no matches
#result(R)      : where to store the result
function getValue() {
    local ilogFile="$1"
    local gexp="$2"
    local notFoundValue="$3"
    local foundExpression=$(grep -oP "$gexp" "$ilogFile")
    if [ -z "$foundExpression" ]; then
        foundExpression="$notFoundValue"
    else
        local result=""
        for match in $foundExpression; do
            append "$result" "$match" "-" result
        done
        foundExpression="$result"
    fi
    eval "$4='$foundExpression'"
}

#Appends two strings with a provided separator
#a		      :	first string
#b		      :	second string
#separator	  :	separator to use
#result(R)	  :	where to store the result
function append() {
	local a="$1"
	local b="$2"
	local separator="$3"
	if [ -z "$a" ]; then
		eval "$4='$b'"
	elif [ -z "$b" ]; then
		eval "$4='$a'"
	else
		eval "$4='${a}${separator}${b}'"
	fi
}

#Appends two paths
#a		            : first path
#b		            : second path
#endWithPathSep		: if the resulting path should be ended with a path separator or not (0: false, >0: true)
#result(R)	      	: where to store the result
function appendPaths() {
	local first=$(echo "$1" | sed "s|\/$||g" )
	local second=$(echo "$2" | sed "s|\/$||g" )
	local endWithPathSep="$3"
	local path=""
	if [ -z "$first" ]; then
		path="$second"
	elif [ -z "$second" ]; then
		path="$first"
	else
		append "$first" "$second" "/" path
	fi
	path=$(echo "$path" | sed "s|\/$||g" )
	if [[ "$endWithPathSep" -ne "0" ]]; then
		path="$path/"	
	fi
	eval "$4='${path}'"
}

#Prepends a given path (treated as directory) to a list of paths
#paths			: the list of paths
#pathToPrepend  : the path to prepend
#separator		: path separator
#result(R)		: the list of paths with the path prepended
function prependDirectoryToPaths() {
	local paths="$1"
	local pathToPrepend="$2"
	local separator="$3"
	local resultPaths=""
	for path in $(echo ${paths} | sed "s|${separator}| |g"); do
		local newPath=""
		appendPaths "$pathToPrepend" "$path" "0" newPath
		if [ -z "$resultPaths" ]; then
			resultPaths="$newPath"
		else
			resultPaths="${resultPaths}${separator}${newPath}"
		fi
	done
	eval "$4='$resultPaths'"
}

#Checks whether getopt works
#result(R)  : where to store the result, 0 for success, 1 for failure.
function checkGetopt() {
    local ecode=0
    getopt --test > /dev/null
    if [[ $? -ne 4 ]]; then
        ecode=1
    fi
    eval "$1='$ecode'"
}
