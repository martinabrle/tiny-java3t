#/bin/sh
Help()
{
   # Display Help
   echo "grant_pgsql_app_user_rights.sh - utility for granting app user CONNECT, USAGE, SELECT, INSERT,"
   echo "                                 UPDATE and DELETE privileges on the target database."
   echo ""
   echo "Syntax: grant_pgsql_app_user_rights.sh [-h|s|d|a|p|n]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     PGSQL server name"
   echo "d     Database name"
   echo "a     Admin's user name"
   echo "p     Admin's password"
   echo "n     App user's name"
   echo
}


# Get the options
dbServerName=""
dbName=""
dbAdminName=""
dbAdminPassword=""
dbUserName=""
while getopts ":h:s:d:a:p:n:" OPT; do
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
      a) # Admin's user name
         dbAdminName=$OPTARG
         ;;
      p) # Admin's password
         dbAdminPassword=$OPTARG
         ;;
      n) # App user's name
         dbUserName=$OPTARG
         ;;
      \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit 1
         ;;
   esac
done

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
if [[ -z "${dbAdminName}" ]]; then
  echo "Error: Database admin's name is empty"
  Help
  exit 1
fi
if [[ -z "${dbAdminPassword}" ]]; then
  echo "Error: Database admin's password is empty"
  Help
  exit 1
fi
if [[ -z "${dbUserName}" ]]; then
  echo "Error: App database user's name is empty"
  Help
  exit 1
fi

dbConnectionString="host=${dbServerName}.postgres.database.azure.com port=5432 dbname=${dbName} user=${dbAdminName} password=${dbAdminPassword} sslmode=require"

echo "GRANT CONNECT ON DATABASE ${dbName} TO ${dbUserName};"> ./app_user_rights.sql
echo "GRANT USAGE ON SCHEMA public TO ${dbUserName};">> ./app_user_rights.sql
echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${dbUserName};">> ./app_user_rights.sql

echo "User '${dbAdminName}' is running the following user creation script:"
cat ./app_user_rights.sql
psql "${dbConnectionString}" --file=./app_user_rights.sql -v ON_ERROR_STOP=1

echo ""
echo "List of existing users:"
psql "${dbConnectionString}" -tAc "SELECT * FROM pg_roles;" -v ON_ERROR_STOP=1
