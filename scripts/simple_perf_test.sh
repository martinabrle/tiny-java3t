#/bin/sh

#infinite loop
for (( c=1; c<=5; c++ ))
do 
   curl -s -X GET http://mabr-tiny-java-ci2.eastus.azurecontainer.io/ > /dev/null
   c=1
done