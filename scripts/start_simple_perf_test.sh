#/bin/sh

#spin 50 processes
for (( c=1; c<=50; c++ ))
do 
   ./simple_perf_test.sh &
done