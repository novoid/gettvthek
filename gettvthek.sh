#!/bin/sh
FILENAME=$(basename $0)

show_help()
{
cat <<EOF

  - Time-stamp: <2013-11-30 12:50:31 vk>
  - Author:     Karl Voit, tools@Karl-Voit.at
  - License:    GPL v3
  - URL:        http://github.com/novoid/gettvthek

  This script takes an URL from ORF-TVthek http://tvthek.orf.at/ and
  extracts a wmv file using streaming. This script was working at
  time-stamp above with Wheezy Debian GNU/Linux and mplayer version
  r34540. Also testes on Mac OS X 10.5.

  Unfortunately, it does not work for programs that consists of 
  multiple parts such as ZIB.

  It might break in case of changes of ORF-TVthek.

  Depends on: cat, sed, grep, wget, mplayer (>= r34540)

  Usage:

  :  ${FILENAME} http://tvthek.orf.at/programs/1211-ZIB-2
                    ... normal invocation

  :  ${FILENAME} -d http://tvthek.orf.at/programs/1211-ZIB-2
                    ... activate debug mode

  :  ${FILENAME} -h 
                    ... show help

EOF
exit 0
}

## known issues:
#i# - does not work with multi-episode streams like ZIB1
#i# - implement URL-checking of $URL and print out error if it is not an TVthek URL


[ "x${1}" = "x" ] && show_help
[ "x${1}" = "x-h" ] && show_help
[ "x${1}" = "x--help" ] && show_help

if [ `uname` = "Linux" ]; then
    SED="/bin/sed"
    MPLAYER="/usr/bin/mplayer"
    WGET="/usr/bin/wget"
    GREP="/bin/grep"
    HEAD="/usr/bin/head"
elif [ `uname` = "Darwin" ]; then
    SED="/usr/bin/sed"
    MPLAYER="/Applications/MPlayer OS X 2.app/Contents/Resources/mplayer.app/Contents/MacOS/mplayer"
    WGET="/usr/local/bin/wget"
    GREP="/usr/bin/grep"
    HEAD="/usr/bin/head"
else
    echo "Error: Operating System is not supported. Only Linux or OS X are supported by now."
    exit 1
fi

DEBUG="false"

[ "x${1}" = "x-d" ] && DEBUG="true"
[ "${DEBUG}" = false ] && URL="${1}"
[ "${DEBUG}" = true ] && URL="${2}"
[ "x${URL}" = "x" ] && show_help
URLFILE=`echo ${URL} | ${SED} 's=.*/=='`
LOGFILE="${FILENAME}.log"

debugthis()
{
        [ "${DEBUG}" = true ] && echo $FILENAME: DEBUG: $@
        echo $FILENAME: DEBUG: $@ >> ${LOGFILE}
        echo "do nothing" >/dev/null
}

errorexit()
{
    debugthis "function myexit($1) called"

    [ "$1" -lt 1 ] && echo "$FILENAME done."
    if [ "$1" -gt 0 ]; then
        echo
	echo ".----------------------------------------------- ${FILENAME}"
	echo "| aborted with errorcode $1:  $2"
	echo "\`-----------------------------------------------"
        echo
        echo "See \"${LOGFILE}\" for further details."
        echo
	echo "${FILENAME}: aborted with errorcode $1:  $2" >> ${LOGFILE}
    fi  

    exit $1
} 

## check, if some files needed are not found
testiffound()
{
    #doreport debug "function testiffound($1) called"

  if [ ! -x "${2}" ]; then
    errorexit 5 "The tool \"${1}\" could not be located: \n|   Missing tool? Please install it.\n|   Wrong link [${2}]? Correct it."
  fi
}


report()
{
    echo " "
    echo ".----------------------------------------------- ${FILENAME}"
    echo "| $@"
    echo "\`-----------------------------------------------"
    echo " "
    echo $FILENAME: $@ >> ${LOGFILE}
}

no_file_found()
{
    echo "Sorry, no file found (as parameter one)."
    exit 1
}


[ -f ${LOGFILE} ] && errorexit 2 "A previous log file [${LOGFILE}] was found.\n| Please check, if there is something important there and/or delete it."

## check for missing tools:
testiffound mplayer "${MPLAYER}"
testiffound sed "${SED}"
testiffound wget "${WGET}"
testiffound grep "${GREP}"

report "I am downloading the stream from \"${URL}\" ..."

debugthis "downloading page source [${URL}]: ${WGET} \"${URL}\""
## e.g. "wget http://tvthek.orf.at/programs/1662-TVthek-special/episodes/4874721-That-s-America"
${WGET} -a ${LOGFILE} "${URL}" || errorexit 3 "wget command unsuccessful"

debugthis "check, if download was successful"
debugthis "URLFILE [${URLFILE}]"
if [ ! -f "${URLFILE}" ]; then
    URLFILE=`echo ${URLFILE} | ${SED} 's#-.*##'`
    debugthis "could not locate URLFILE, trying with new URLFILE [${URLFILE}] ..."
    [ -f "${URLFILE}" ] || no_file_found "wget-download of \"${URL}\" as \"${URLFILE}\""
fi

## FIXXME: if no URLFILE is found, remove everything from URLFILE behind "-" and use as new URLFILE


## 2013-11-30 works: 
## grep -i wmv 1309553-Was-gibt-es-Neues- | grep "video_stream_url" | head -n 1 | sed 's#.*video_stream_url":"worldwide\\\/##' | sed 's#","video_file_name.*##'
## ... results in ...
## 2013-11-29_2200_sd_01_WAS-GIBT-ES-NEUES-_____7180997__o__0000938770__s7187676___s__ORF1HiRes_21593721P_22374601P.wmv

debugthis "extracting WMVFILE from URLFILE [${URLFILE}] ..."
WMVFILE=`${GREP} -i wmv ${URLFILE} | ${GREP} "video_stream_url" | ${HEAD} -n 1 | ${SED} 's#.*video_stream_url":"worldwide\\\/##' | ${SED} 's#","video_file_name.*##'` || errorexit 4 "could not extract WMVFILE name from URLFILE [${URLFILE}]."

debugthis "WMVFILE [${WMVFILE}]"

debugthis "extracting DURATION from ASXFILE"
DURATION=`cat ${URLFILE} | ${GREP} "duration_as_string" | ${HEAD} -n 1 | ${SED} 's/.*duration_as_string":"//' | ${SED} 's/",".*//'`
debugthis "DURATION [$DURATION]"

debugthis "generating OUTPUTFILE from STREAMURL"
OUTPUTFILE="${WMVFILE}"
debugthis "OUTPUTFILE [$OUTPUTFILE]"

debugthis "generating STREAMURL from WMVFILE [$WMVFILE] ..."
STREAMURL="mms://apasf.apa.at/cms-worldwide/${WMVFILE}"
debugthis "STREAMURL [$STREAMURL]"


## 2013-11-30 works:
## grep -i wmv 1309553-Was-gibt-es-Neues- | grep "video_stream_url" | head -n 1 | sed 's#.*video_stream_url":"worldwide\
## mplayer -dumpstream mms://apasf.apa.at/cms-worldwide/2013-11-29_2200_sd_01_WAS-GIBT-ES-NEUES-_____7180997__o__0000938770__s7187676___s__ORF1HiRes_21593721P_22374601P.wmv -dumpfile "out.wmv"

report "getting \"${OUTPUTFILE}\"\n|  ... which will take ${DURATION} ...\n|  (some initial error messages might be OK)"
debugthis "will execute: ${MPLAYER} -quiet -dumpstream "${STREAMURL}" -dumpfile "${OUTPUTFILE}""
"${MPLAYER}" -quiet -dumpstream "${STREAMURL}" -dumpfile "${OUTPUTFILE}" || errorexit 6 "grabbing stream unsuccessful (${STREAMURL})"

report "finished fetching ${OUTPUTFILE}"
rm "${URLFILE}"  || errorexit 10 "could not delete URLFILE [${URLFILE}]."
debugthis "succesfully finished."
sync; sleep 1
## remove LOGFILE only if DEBUG is disabled and everything above did turn out great:
[ "${DEBUG}" = false ] && rm "${LOGFILE}" || echo "could not delete LOGFILE [${LOGFILE}] or DEBUG mode was activated.."


#end
