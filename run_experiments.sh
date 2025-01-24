#!/bin/bash

source BashUtils/utils.sh
DEBUG=1

#set -x #Comment to disable debug output of this script (this is a full verbosity mode; you should use the debug functionality from utils.sh instead)

getoptWorks=""
checkGetopt getoptWorks
if [[ "$getoptWorks" -eq "0" ]]; then
    debug "getopt is working" 
else
    error "getopt command is not working, please check that getopt is installed and available" 1
fi

LONGOPTIONS=seedsFile:,outputFile:,defects4jProject:,defects4jVersion:,randoopOutputLimit:,seedIndexBegin:,seedIndexEnd:,help
OPTIONS=s:,o:,P:,V:,L:,B:,E:,h

#Display script usage
#error : if 0 the usage comes from normal behaviour, if > 0 then it comes from an error and will exit with this as exit code
#extra information : an additional message
function usage() {
    local code="$1"
    local extraMsg="$2"
    local msg="Runs field extensions correlation experiments.\nUsage:\nrun_experiments.sh -[-h]elp to show this message\nrun_experiments.sh -[-s]eedsFile <path> -[-o]utputFile <path> -[-]defects4j[P]roject <string> -[-]d4jVersion <int> -[-]randoopOutput[L]imit <int> -[-]seedIndex[B]egin <int> -[-]seedIndex[E]nd <int>n\tSeed file (.txt) is a file with one random number per line.\n\tOutput file (.csv) is a file where the outputs will be saved, if the file does not exist it will be created with the columns' headers; if the file exist the results will be appended to it.\n\tDefects4j Project it's a Defects4j Project Name\n\tDefects4j Version is the defects4j Project specific version\n\tSeed index begin and end represent the lines that will be used from the Seeds file (they must be valid indexes)."
    if [[ "$code" -eq "0" ]]; then
        [ ! -z "$extraMsg" ] && infoMessage "$extraMsg"
        infoMessage "$msg"
        exit 0
    else
        if [ -z "$extraMsg" ]; then
            error "Wrong usage\n$msg" "$code"
        else
            error "Wrong usage\n${extraMsg}\n$msg" "$code"
        fi
    fi
}

#Arguments
seedsFile=""
seedsFileSet=0
outputFile=""
outputFileSet=0
randOLimit=0
randOLimitSet=0
d4jProject=""
d4jProjectSet=0
d4jVersion=0
d4jVersionSet=0
seedBegin=0
seedBeginSet=0
seedEnd=0
seedEndSet=0

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
getoptExitCode="$?"
if [[ "$getoptExitCode" -ne "0" ]]; then
    error "Error while parsing arguments ($getoptExitCode)" 1
fi

eval set -- "$PARSED"

while true; do
	case "$1" in
		--seedsFile | -s)
			seedsFile="$2"
			[ -z "$seedsFile" ] || $(echo "$seedsFile" | egrep -q "^[[:space:]]+$") && error "Seed file path (${seedsFile}) is empty or contains only spaces" 2
			$(echo "$seedsFile" | egrep -qv ".*\.txt$") && error "seed file ($seedsFile) does not have extension '.txt'" 3
			[ ! -f "$seedsFile" ] && error "Seed file ($seedsFile) does not exists or is not a file" 4
			seedsFileSet=1
			shift 2
		;;
		--outputFile | -o)
			outputFile="$2"
			[ -z "$outputFile" ] || $(echo "$outputFile" | egrep -q "^[[:space:]]+$") && error "Output file path (${outputFile}) is empty or contains only spaces" 5
			$(echo "$outputFile" | egrep -qv ".*\.csv$") && error "Output file ($outputFile) does not have extension '.csv'" 6
			outputFileSet=1
			shift 2
		;;
		--randoopOutputLimit | -L)
		    randOLimit="$2"
		    $(echo "$randOLimit" | grep -qE "^[[:digit:]]+$") || error "Randoop output limit must be a positive number ($randOLimit)" 7
		    randOLimitSet=1
		    shift 2
		;;
		--defects4jProject | -P)
			d4jProject="$2"
			[ -z "$d4jProject" ] || $(echo "$d4jProject" | egrep -q "^[[:space:]]+$") && error "Defects4j Project (${d4jProject}) is empty or contains only spaces" 8
			d4jProjectSet=1
			shift 2
		;;
		--defects4jVersion | -V)
		    d4jVersion="$2"
		    $(echo "$d4jVersion" | grep -qE "^[[:digit:]]+$") || error "Defects4j Project's version must be a positive number ($d4jVersion)" 9
		    d4jVersionSet=1
		    shift 2
		;;
		--seedIndexBegin | -B)
		    seedBegin="$2"
		    $(echo "$seedBegin" | grep -qE "^[[:digit:]]+$") || error "Seed index begin must be a positive number ($seedBegin)" 10
		    seedBeginSet=1
		    shift 2
		;;
		--seedIndexEnd | -E)
		    seedEnd="$2"
		    $(echo "$seedEnd" | grep -qE "^[[:digit:]]+$") || error "Seed index end must be a positive number ($seedEnd)" 11
		    seedEndSet=1
		    shift 2
		;;
		--help | -h)
			usage 0 ""
		;;
		--)
			shift
			break
		;;
		*)
			error "Invalid arguments" 100
		;;
	esac
done

[[ "$seedsFileSet" -ne "1" ]] && usage 12 "Seed file was not set"
[[ "$outputFileSet" -ne "1" ]] && usage 13 "Output file was not set"
if [[ "$randOLimitSet" -ne "1" ]]; then
	randOLimit=1000
	randOLimitSet=1
	warning "Randoop output limit was not set, will use 1000 instead"
fi
[[ "$d4jProjectSet" -ne "1" ]] && usage 14 "Defects4j project was not set"
[[ "$d4jVersionSet" -ne "1" ]] && usage 15 "Defects4j projects's version was not set"
if [[ "$seedBeginSet" -ne "1" ]]; then
	seedBegin=1
	seedBeginSet=1
	warning "Seed begin was not set, will use 1 instead"
fi
[[ "$seedEndSet" -ne "1" ]] && usage 16 "Seed end was not set"

infoMessage "Checking defects4j project ($d4jProject) ..."
defects4j info -p "$d4jProject"
projectCheck=$?
if [[ "$projectCheck" -ne "0" ]]; then
	error "Invalid defects4j project ($d4jProject)" 17
fi

infoMessage "Checking defects4j version ($d4jVersion) for project ($d4jProject) ..."
defects4j info -p "$d4jProject" -b "$d4jVersion"
versionCheck=$?
if [[ "$versionCheck" -ne "0" ]]; then
	error "Invalid defects4j version ($d4jVersion) for project ($d4jProject)" 18
fi


infoMessage "Checking seeds file and indexes ..."
availableSeeds=$(cat "$seedsFile" | wc -l)
if [[ "$availableSeeds" -eq "0" ]]; then
	error "No available seeds in seeds file ($seedsFile)" 19
fi
if [[ "$seedBegin" -gt "$seedEnd" ]]; then
	error "seedIndexBegin ($seedBegin) is greater than seedIndexEnd ($seedEnd)" 20
fi
if [[ "$seedEnd" -gt "$availableSeeds" ]]; then
	error "seedIndexEnd ($seedEnd) is greater than amount of seeds ($availableSeeds) in seeds file ($seedsFile)" 21
fi

infoMessage "Checking and initializing output file ($outputFile) ..."
appendHeaders=0
if [[ ! -e "$outputFile" ]]; then
	touch "$outputFile"
	appendHeaders=1
fi
[ -s "$outputFile" ] || appendHeaders=1
if [[ "$appendHeaders" -eq "1" ]]; then
	headers=""
	append "$headers" "Project_id" "," headers
	append "$headers" "Version_id" "," headers
	append "$headers" "seed" "," headers
	append "$headers" "Time_budget" "," headers
	append "$headers" "Size_budget" "," headers
	append "$headers" "Objects_total" "," headers
	append "$headers" "Objects_different" "," headers
	append "$headers" "Fields_total" "," headers
	append "$headers" "Fields_different" "," headers
	append "$headers" "Variability_objs" "," headers
	append "$headers" "Variability_fields" "," headers
	append "$headers" "Bug_detected" "," headers
	append "$headers" "Bug_detected_tests" "," headers
	append "$headers" "lines_total" "," headers
	append "$headers" "lines_covered" "," headers
	append "$headers" "lines_coverage" "," headers
	append "$headers" "branches_total" "," headers
	append "$headers" "branches_covered" "," headers
	append "$headers" "branches_coverage" "," headers
	echo "${headers}" >> "$outputFile"
fi

for seed_index in $(eval echo {$seedBegin..$seedEnd}); do
	seed=$(sed ${seed_index}'!d' "$seedsFile")
	infoMessage "Running seed $seed for project $d4jProject, version $d4jVersion; randoop output limit $randOLimit ..."
	
	infoMessage "Running test generation with Randoop ..."
	genTestsOutput="${d4jProject}_${d4jVersion}f_${randOLimit}_n${seed}"
	genCommand="gen_tests.pl -g randoop -p ${d4jProject} -v ${d4jVersion}f -n ${seed} -o ${genTestsOutput} -b 3600 -l ${randOLimit} -s ${seed}"
	debug "Gentest command\n$genCommand"
	$genCommand
	genTestsOK=$?
	if [[ "$genTestsOK" -ne "0" ]]; then
		error "Randoop test generation failed! (error code: ${genTestsOK})" 22
	fi
	fieldExtensionsFile="${d4jProject}_${d4jVersion}f_s${seed}_field_extensions.log"
	mv "field_coverage.log" "$fieldExtensionsFile"
	objTotal=$(cat "$fieldExtensionsFile" | grep -oE "^Objects Seen:.*$" | sed "s|Objects Seen: ||g")
	objDist=$(cat "$fieldExtensionsFile" | grep -oE "^Distinct Objects Seen:.*$" | sed "s|Distinct Objects Seen: ||g")
	fieldsTotal=$(cat "$fieldExtensionsFile" | grep -oE "^Fields Seen:.*$" | sed "s|Fields Seen: ||g")
	fieldsDist=$(cat "$fieldExtensionsFile" | grep -oE "^Distinct Fields Seen:.*$" | sed "s|Distinct Fields Seen: ||g")
	objVariability=$(echo "scale=6 ; ($objDist / $objTotal) * 100" | bc)
	fieldsVariability=$(echo "scale=6 ; ($fieldsDist / $fieldsTotal) * 100" | bc)
	testSuitesArchiveDir="${genTestsOutput}/${d4jProject}/randoop/${seed}/"
	
	infoMessage "Running bug detection ..."
	bugDetectionOutput="${genTestsOutput}_bug-detection"
	bugDetectionCommand="run_bug_detection.pl -p $d4jProject -d $testSuitesArchiveDir -o ${bugDetectionOutput} -v ${d4jVersion}f"
	debug "Bugdetection command\n$bugDetectionCommand"
	$bugDetectionCommand
	bugDetectionOK=$?
	if [[ "$bugDetectionOK" -ne "0" ]]; then
		error "Bug detection analysis failed! (error code: ${bugDetectionOK})" 23
	fi
	bugDetectionFile="${bugDetectionOutput}/bug_detection"
	bugDetectedTests=$(sed '2!d' "${bugDetectionFile}" | cut -d ',' -f6 | tr -d '[:space:]')
	bugDetected=0
	if [[ "$bugDetectedTests" -gt "0" ]]; then
		bugDetected=1
	fi
	
	infoMessage "Running coverage ..."
	coverageOutput="${genTestsOutput}_coverage"
	coverageFile="${coverageOutput}/coverage"
	coverageCommand="run_coverage.pl -p $d4jProject -d $testSuitesArchiveDir -o $coverageOutput -v ${d4jVersion}f"
	debug "Coverage command\n$coverageCommand"
	$coverageCommand
	coverageOK=$?
	if [[ "$coverageOK" -ne "0" ]]; then
		error "Coverage analysis failed! (error code: ${coverageOK})" 24
	fi
	linesTotal=$(sed '2!d' "${coverageFile}" | cut -d ',' -f5  | tr -d '[:space:]')
	linesCovered=$(sed '2!d' "${coverageFile}" | cut -d ',' -f6  | tr -d '[:space:]')
	branchesTotal=$(sed '2!d' "${coverageFile}" | cut -d ',' -f7  | tr -d '[:space:]')
	branchesCovered=$(sed '2!d' "${coverageFile}" | cut -d ',' -f8  | tr -d '[:space:]')
	linesCoverage=$(echo "scale=6 ; ($linesCovered / $linesTotal) * 100" | bc)
	branchesCoverage=$(echo "scale=6 ; ($branchesCovered / $branchesTotal) * 100" | bc)
	
	dataLine=""
	append "$dataLine" "${d4jProject}" "," dataLine
	append "$dataLine" "${d4jVersion}" "," dataLine
	append "$dataLine" "${seed}" "," dataLine
	append "$dataLine" "3600" "," dataLine
	append "$dataLine" "${randOLimit}" "," dataLine
	append "$dataLine" "${objTotal}" "," dataLine
	append "$dataLine" "${objDist}" "," dataLine
	append "$dataLine" "${fieldsTotal}" "," dataLine
	append "$dataLine" "${fieldsDist}" "," dataLine
	append "$dataLine" "${objVariability}" "," dataLine
	append "$dataLine" "${fieldsVariability}" "," dataLine
	append "$dataLine" "${bugDetected}" "," dataLine
	append "$dataLine" "${bugDetectedTests}" "," dataLine
	append "$dataLine" "${linesTotal}" "," dataLine
	append "$dataLine" "${linesCovered}" "," dataLine
	append "$dataLine" "${linesCoverage}" "," dataLine
	append "$dataLine" "${branchesTotal}" "," dataLine
	append "$dataLine" "${branchesCovered}" "," dataLine
	append "$dataLine" "${branchesCoverage}" "," dataLine
	
	echo "${dataLine}" >> "$outputFile"
done
