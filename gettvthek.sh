#!/bin/sh
URL="${1}"
FILENAME=$(basename $0)
if [ "x${URL}" = "x" ]; then
cat <<EOF

  Time-stamp: <2012-11-07 17:54:45 vk>
  Author: Karl Voit, tools@Karl-Voit.at
  License: GPL v3
  URL: http://github.com/novoid/gettvthek

  This script takes an ORF-TVthek URL from command line and extracts a wmv file 
  using streaming. This script was working at time-stamp above with GNU/Linux 
  and mplayer version r34540. It might break in case of changes of ORF-TVthek.

  Depends on: cat, sed, grep, wget, mplayer (>= r34540)

  Enabling debug mode: please edit "$0" in function "debugthis()".

  Usage:    ${FILENAME} http://tvthek.orf.at/programs/1211-ZIB-2

EOF
exit 0
fi

URLFILE=`echo ${URL} | sed 's=.*/=='`
LOGFILE="${FILENAME}.log"

debugthis()
{
## please remove the comment character in the next line for enabling debug mode:
#        echo $FILENAME: DEBUG: $@
        echo $FILENAME: DEBUG: $@ >> ${LOGFILE}
        echo "do nothing" >/dev/null
}

report()
{
    echo "-----------------------------------------------"
        echo "$FILENAME: $@"
    echo "-----------------------------------------------"
        echo $FILENAME: $@ >> ${LOGFILE}
}

no_file_found()
{
    echo "Sorry, no file found (as parameter one)."
    exit 1
}

errorexit()
{
    debugthis "function myexit($1) called"

    [ "$1" -lt 1 ] && echo "$FILENAME done."
    if [ "$1" -gt 0 ]; then
        print_help
        echo
        echo "$FILENAME aborted with errorcode $1:  $2"
        echo "see \"${LOGFILE}\" for further details."
        echo
    fi  

    exit $1
} 

[ -f ${LOGFILE} ] && 1 "A previous log file [${LOGFILE}] was found. Please check, if there is something important there and/or delete it."

report "I am downloading the stream from \"${URL}\" ..."

debugthis "downloading page source [${URL}]: wget \"${URL}\""
## e.g. "wget http://tvthek.orf.at/programs/1662-TVthek-special/episodes/4874721-That-s-America"
wget -a ${LOGFILE} "${URL}" || errorexit 2 "wget command unsuccessful"

debugthis "check, if download was successful"
[ -f "${URLFILE}" ] || no_file_found "wget-download of \"${URL}\" as \"${URLFILE}\""

debugthis "get asx-URL after \"embed\""
## e.g. "/programs/1662-TVthek-special/episodes/4874721-That-s-America/4886459-20121106222015773.asx"
ASXURL=`grep -A 5 embed "${URLFILE}" | grep src | sed 's/.*="//'|sed 's/"//'`

debugthis "downloading asx-URL http://tvthek.orf.at[$ASXURL]: wget \"http://tvthek.orf.at${ASXURL}\""
## e.g. wget http://tvthek.orf.at`grep -A 5 embed 4874721-That-s-America | grep src | sed 's/.*="//'|sed 's/"//'
wget -a ${LOGFILE} "http://tvthek.orf.at${ASXURL}" || errorexit 4 "wget of ASX file (${ASXFILE}) was unsuccessful."

debugthis "extracting ASXFILE from ASXURL"
ASXFILE=`echo ${ASXURL} | sed 's=.*/=='`

debugthis "check, if ASXFILE could be found"
[ -f "${ASXFILE}" ] || no_file_found "wget-download of \"${ASXURL}\" as \"${ASXFILE}\""

debugthis "extract mms-stream from asx file [$ASXFILE]: cat \"${ASXFILE}\" | sed 's/.*mms:/mms:/' | sed 's/.wmv.*/.wmv/'"
## e.g. "cat 4886459-20121106222015773.asx | sed 's/.*mms:/mms:/' | sed 's/.wmv.*/.wmv/'"
##       mms://apasf.apa.at/cms-worldwide/2012-11-06_2230_sd_02_THAT-S-AMERICA_____4874721__o__0000309993__s4886459___73_ORF2HiRes_22325512P_23123810P.wmv%
MMSURL=`cat "${ASXFILE}" | sed 's/.*mms:/mms:/' | sed 's/.wmv.*/.wmv/'`
debugthis "MMSURL [$MMSURL]"

debugthis "extracting DURATION from ASXFILE"
DURATION=`cat ${ASXFILE} | grep duration | sed 's/.*duration value="//' | sed 's/\..*//' | sed 's/:/h/' | sed 's/:/m/'`"s"
debugthis "DURATION [$DURATION]"

debugthis "generating OUTPUTFILE from MMSURL"
OUTPUTFILE=`echo ${MMSURL} | sed 's=.*/==' | sed 's/___.*//' | sed 's/.asx//'`_${DURATION}.wmv
debugthis "OUTPUTFILE [$OUTPUTFILE]"

report "getting \"${OUTPUTFILE}\" which will take ${DURATION} ...  (some initial error msg might be OK)"
debugthis "will execute: mplayer -msglevel all=1 -dumpstream "${MMSURL}" -dumpfile "${OUTPUTFILE}""
## e.g. vk@gary ~2d % mplayer -dumpstream mms://apasf.apa.at/cms-worldwide/2012-11-06_2230_sd_02_THAT-S-AMERICA_____4874721__o__0000309993__s4886459___73_ORF2HiRes_22325512P_23123810P.wmv -dumpfile 2012-11-06_2230_sd_02_THAT-S-AMERICA.wmv
mplayer -msglevel all=1 -dumpstream "${MMSURL}" -dumpfile "${OUTPUTFILE}"  || errorexit 4 "grabbing stream unsuccessful (${MMSURL})"

report "finished fetching ${OUTPUTFILE}"
rm "${ASXFILE}"  || errorexit 10 "could not delete ASXFILE [${ASXFILE}]."
rm "${URLFILE}"  || errorexit 11 "could not delete URLFILE [${URLFILE}]."
debugthis "succesfully finished."

## remove LOGFILE only if everything above did turn out great:
rm "${LOGFILE}"

#end
