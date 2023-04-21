#/bin/sh
Help()
{
   # Display Help
   echo "create_aad_db.sh - utility for creating a database on an AAD enabled"
   echo "                           Azure PGSQL flexi server"
   echo ""
   echo "Syntax: create_aad_db.sh [-h|s|d|a]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     PGSQL server name"
   echo "d     Database name"
   echo "a     AAD Admin's user name"
   echo
}

# Get the options
dbServerName=""
dbName=""
dbAADAdminName=""
while getopts ":h:s:d:a:p:n:o:b:" OPT; do
   case $OPT in
      h) # display Help
        Help
        # exit 1
        ;;
      s) # Server name
        dbServerName=$OPTARG
        ;;
      d) # database name
         dbName=$OPTARG
         ;;
      a) # Admin's AAD user name
         dbAADAdminName=$OPTARG
         ;;
      \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit 1
         ;;
   esac
done

echo "dbServerName: '${dbServerName}'"
echo "dbName: '${dbName}'"
echo "dbAADAdminName: '${dbAADAdminName}'"

if [[ -z "${dbServerName}" ]]; then
  echo "Error: Database server name is empty"
  Help
  exit 1
fi

if [[ -z "${dbName}" ]]; then
  echo "Error: Database name is empty"
  Help
  exit 1
fi
if [[ -z "${dbAADAdminName}" ]]; then
  echo "Error: Database AAD admin's name is empty"
  Help
  exit 1
fi
if [[ -z "${PGPASSWORD}" ]]; then
  echo "Error: variable PGPASSWORD is empty; it should contain a valid token"
  Help
  exit 1
fi

dbDatabaseExists=`psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d postgres -U "${dbAADAdminName}"  -XtAc "SELECT 1 FROM pg_database WHERE datname='${dbName}';" -v ON_ERROR_STOP=1`

if [[ "${dbDatabaseExists}" != "1" ]]; then
  echo "Database '${dbName}' does not exist yet, creating the database"
  psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d postgres -U "${dbAADAdminName}"  -XtAc "CREATE DATABASE ${dbName};" -v ON_ERROR_STOP=1
else
  echo "Database '${dbName}' does already exists"
fi
