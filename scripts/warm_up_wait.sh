#/bin/sh
Help()
{
   # Display Help
   echo "warm_up_wait.sh - utility which waits, until a service behind a URL"
   echo "                  provided comes online"
   echo ""
   echo "Syntax: warm_up_wait.sh [-h|u|s|d]"
   echo "options:"
   echo "h     Print this Help."
   echo "u     Url"
   echo "s     Startup max. delay"
   echo "d     Shutdown max. delay"
   echo
}

# Get the options
maxShutdownDelaySec=80
maxStartUpDelaySec=500
url=""

while getopts ":u:s:d:" OPT; do
   case $OPT in
      h) # display Help
        Help
        # exit 1
        ;;
      u) # URL
        url=$OPTARG
        ;;
      s) # Startup max wait
         maxStartUpDelaySec=$OPTARG
         ;;
      d) # Shutdown max wait
         maxShutdownDelaySec=$OPTARG
         ;;
      \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit 1
         ;;
   esac
done

if [[ -z "${url}" ]]; then
  echo "Error: Url is empty"
  Help
  exit 1
fi

stepSec=5
noOfAttempts=0

currentDateTime=`date`
echo "Starting the warm-up check: ${currentDateTime}"

shutdown_wait=$maxShutdownDelaySec
status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null "${url}")
echo "Service status '${status_code}', shutdown_wait '${shutdown_wait}'"
while [[ "$status_code" == '200' && $shutdown_wait -gt 0 ]]; do
    echo "Service not down yet (status '${status_code}', shutdown_wait '${shutdown_wait}')"
    shutdown_wait=$(($shutdown_wait-$stepSec))
    noOfAttempts=$(($noOfAttempts+1))
    sleep $stepSec
    status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null "${url}")
done
currentDateTime=`date`
echo "Finnished the shutdown wait: ${currentDateTime}"

warmup_wait=$maxStartUpDelaySec
status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null "${url}")
echo "Service status '${status_code}', warmup_wait '${warmup_wait}'"
while [[ "$status_code" != '200' && $warmup_wait -gt 0 ]]; do
    echo "Service not online yet (status '${status_code}', warmup_wait '${warmup_wait}')"
    warmup_wait=$(($warmup_wait-$stepSec))
    noOfAttempts=$(($noOfAttempts+1))
    sleep $stepSec
    status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null "${url}")
done

currentDateTime=`date`
echo "Finnished the warm-up wait: ${currentDateTime}"
echo "Service warm up finished after ${noOfAttempts} attempts with status_code '${status_code}'"

if [[ "${status_code}" == "200" ]]; then
  echo "Finished: Service warm up finished after ${noOfAttempts} attempts with status_code '${status_code}'"
else
  echo "Failed: Service warm up failed after ${noOfAttempts} attempts with status_code '${status_code}'"
  exit 1
fi