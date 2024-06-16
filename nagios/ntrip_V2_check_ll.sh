#!/bin/bash
# Add current directory ot the path for making testing simpler
export PATH="$PATH:."

# Force Temp Dir to have path
#[[ "${TMPDIR}" != */ ]] && TMPDIR="${TMPDIR}/"

# Remove the / from TMPDire if it exists

TMPDIR=${TMPDIR%/}


# Check if the number of parameters is 5 or 7
if [ "$#" -eq 5 ] || [ "$#" -eq 7 ]
then
    SERVER=$1
    PORT=$2
    BASE=$3
    LAT=$4
    LONG=$5
    NTRIP_SERVER=$SERVER:$PORT
    AUTH=
    if [ "$#" -eq 7 ]
    then
        AUTH="-u "$6":"$7
    fi
else
    echo "Unknown - Usage: server port BASE LAT LONG [USER PASS]"
    echo "You need to provide either 5 or 7 parameters."
    exit 1
fi

# Your script logic here

if [ -z $5 ]
then
    exit 3
fi



command -v ntrip_V2_check_ll.awk &>/dev/null || {  echo  "Unknown - I require ntrip_V2_check_ll.awk but it's not installed.  Aborting."; exit 3; }

#curl  --http0.9 --silent -f $AUTH --connect-timeout 10  -H "Ntrip-Version: Ntrip/1.0" -H "User-Agent: NTRIP CURL_NTRIP_TEST/0.1"  http://$NTRIP_SERVER/ | tr -d \\r | tee log| NTRIP_V2_CHECK_LL.awk $SERVER $BASE $LAT $LONG

# Curl will return string of the form HTTP_CODE=Error code when something goes wrong.

CURL_STR=$(curl  --dump-header $TMPDIR/$$.head --output $TMPDIR/$$.body --http0.9 --silent --fail-with-body -w "HTTP_CODE=%{http_code};" $AUTH --connect-timeout 10  -H "Ntrip-Version: Ntrip/2.0" -H "User-Agent: NTRIP CURL_NTRIP_TEST/0.1"  http://$NTRIP_SERVER/)
curl_exit_status=$?
eval $CURL_STR

#echo $HTTP_CODE


# Check if curl failed to connect
if [ $curl_exit_status -ne 0 ]; then
    case $curl_exit_status in
        6)
            echo "NTRIP_V2_CHECK_LL CRITICAL - " HOST ": Could not resolve host: " $0;
            ;;
        7)
            echo "NTRIP_V2_CHECK_LL CRITICAL - " HOST ": Failed to connect to host: " $0;
            ;;
        28)
            echo "NTRIP_V2_CHECK_LL CRITICAL - " HOST ": Operation timed out: " $0;
            ;;
        35)
            echo "NTRIP_V2_CHECK_LL CRITICAL - " HOST ": SSL connect error: " $0;
            ;;
        *)
            echo "NTRIP_V2_CHECK_LL CRITICAL - " HOST ": Failed to connect to $URL. Curl exit status: $curl_exit_status: " $0;
            ;;
    esac
    exit 1
fi

cat $TMPDIR/$$.body | tr -d \\r | ntrip_V2_check_ll.awk $SERVER $BASE $LAT $LONG


result=$?
if [ $result -gt 3 ]
then
   exit 3
fi

exit $result
