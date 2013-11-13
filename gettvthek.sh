#!/bin/sh
FILENAME=$(basename $0)

show_help()
{
cat <<EOF

  - Time-stamp: <2013-11-13 19:16:08 vk>
  - Author:     Karl Voit, tools@Karl-Voit.at
  - License:    GPL v3
  - URL:        http://github.com/novoid/gettvthek

  This script takes an URL from ORF-TVthek http://tvthek.orf.at/ and
  extracts a wmv file using streaming. This script was working at
  time-stamp above with Wheezy Debian GNU/Linux and mplayer version
  r34540. It might break in case of changes of ORF-TVthek.

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

SED="/bin/sed"
MPLAYER="/usr/bin/mplayer"
WGET="/usr/bin/wget"
GREP="/bin/grep"

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


[ -f ${LOGFILE} ] && errorexit 1 "A previous log file [${LOGFILE}] was found.\n| Please check, if there is something important there and/or delete it."

## check for missing tools:
testiffound mplayer ${MPLAYER}
testiffound sed ${SED}
testiffound wget ${WGET}
testiffound grep ${GREP}

report "I am downloading the stream from \"${URL}\" ..."

debugthis "downloading page source [${URL}]: ${WGET} \"${URL}\""
## e.g. "wget http://tvthek.orf.at/programs/1662-TVthek-special/episodes/4874721-That-s-America"
${WGET} -a ${LOGFILE} "${URL}" || errorexit 2 "wget command unsuccessful"

debugthis "check, if download was successful"
[ -f "${URLFILE}" ] || no_file_found "wget-download of \"${URL}\" as \"${URLFILE}\""

debugthis "get asx-URL after \"embed\""
## e.g. "/programs/1662-TVthek-special/episodes/4874721-That-s-America/4886459-20121106222015773.asx"
ASXURL=`${GREP} -A 5 embed "${URLFILE}" | ${GREP} src | ${SED} 's/.*="//'|${SED} 's/"//'`

debugthis "downloading asx-URL http://tvthek.orf.at[$ASXURL]: ${WGET} \"http://tvthek.orf.at${ASXURL}\""
## e.g. wget http://tvthek.orf.at`grep -A 5 embed 4874721-That-s-America | grep src | sed 's/.*="//'|sed 's/"//'
${WGET} -a ${LOGFILE} "http://tvthek.orf.at${ASXURL}" || errorexit 4 "wget of ASX file (${ASXFILE}) was unsuccessful."

debugthis "extracting ASXFILE from ASXURL"
ASXFILE=`echo ${ASXURL} | ${SED} 's=.*/=='`

debugthis "check, if ASXFILE could be found"
[ -f "${ASXFILE}" ] || no_file_found "wget-download of \"${ASXURL}\" as \"${ASXFILE}\""

debugthis "extract mms-stream from asx file [$ASXFILE]: cat \"${ASXFILE}\" | ${SED} 's/.*mms:/mms:/' | ${SED} 's/.wmv.*/.wmv/'"
## e.g. "cat 4886459-20121106222015773.asx | sed 's/.*mms:/mms:/' | sed 's/.wmv.*/.wmv/'"
##       mms://apasf.apa.at/cms-worldwide/2012-11-06_2230_sd_02_THAT-S-AMERICA_____4874721__o__0000309993__s4886459___73_ORF2HiRes_22325512P_23123810P.wmv%
MMSURL=`cat "${ASXFILE}" | ${SED} 's/.*mms:/mms:/' | ${SED} 's/.wmv.*/.wmv/'`
debugthis "MMSURL [$MMSURL]"

debugthis "extracting DURATION from ASXFILE"
DURATION=`cat ${ASXFILE} | ${GREP} duration | ${SED} 's/.*duration value="//' | ${SED} 's/\..*//' | ${SED} 's/:/h/' | ${SED} 's/:/m/'`"s"
debugthis "DURATION [$DURATION]"

debugthis "generating OUTPUTFILE from MMSURL"
OUTPUTFILE=`echo ${MMSURL} | ${SED} 's=.*/==' | ${SED} 's/___.*//' | ${SED} 's/.asx//'`_${DURATION}.wmv
debugthis "OUTPUTFILE [$OUTPUTFILE]"

report "getting \"${OUTPUTFILE}\" which will take ${DURATION} ...\n|  (some initial error messages might be OK)"
debugthis "will execute: ${MPLAYER} -msglevel all=1 -dumpstream "${MMSURL}" -dumpfile "${OUTPUTFILE}""
## e.g. vk@gary ~2d % mplayer -dumpstream mms://apasf.apa.at/cms-worldwide/2012-11-06_2230_sd_02_THAT-S-AMERICA_____4874721__o__0000309993__s4886459___73_ORF2HiRes_22325512P_23123810P.wmv -dumpfile 2012-11-06_2230_sd_02_THAT-S-AMERICA.wmv
"${MPLAYER}" -msglevel all=1 -dumpstream "${MMSURL}" -dumpfile "${OUTPUTFILE}" || errorexit 4 "grabbing stream unsuccessful (${MMSURL})"

report "finished fetching ${OUTPUTFILE}"
rm "${ASXFILE}"  || errorexit 10 "could not delete ASXFILE [${ASXFILE}]."
rm "${URLFILE}"  || errorexit 11 "could not delete URLFILE [${URLFILE}]."
debugthis "succesfully finished."
sync; sleep 1
## remove LOGFILE only if DEBUG is disabled and everything above did turn out great:
[ "${DEBUG}" = false ] && rm "${LOGFILE}" || echo "could not delete LOGFILE [${LOGFILE}] or DEBUG mode was activated.."

#end
