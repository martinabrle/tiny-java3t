#/bin/sh
Help()
{
   # Display Help
   echo "create_pgsql_user.sh - utility for creating classic PGSQL users on Azure "
   echo "                       and granting them CONNECT, USAGE, SELECT, INSERT,"
   echo "                       UPDATE and DELETE privileges on the target database."
   echo ""
   echo "Syntax: create_pgsql_user.sh [-h|n|s|d|a|p|n|m]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     PGSQL server name"
   echo "d     Database name"
   echo "a     Admin's user name"
   echo "p     Admin's password"
   echo "n     New user's name"
   echo "m     New user's password"
   echo
}

# Get the options
dbServerName=""
dbName=""
dbAdminName=""
dbAdminPassword=""
dbUserName=""
dbUserPassword=""
while getopts ":h:s:d:a:p:n:m:" OPT; do
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
      n) # New user's name
         dbUserName=$OPTARG
         ;;
      m) # New user's password
         dbUserPassword=$OPTARG
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
  echo "Error: New database user's name is empty"
  Help
  exit 1
fi
if [[ -z "${dbUserPassword}" ]]; then
  echo "Error: New database user's password is empty"
  Help
  exit 1
fi

dbConnectionString="host=${dbServerName}.postgres.database.azure.com port=5432 dbname=${dbName} user=${dbAdminName} password=${dbAdminPassword} sslmode=require"
#echo "${dbConnectionString}"
dbUserExists=`psql "${dbConnectionString}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${dbUserName}';"`

if [[ $dbUserExists -ne '1' ]]; then
  echo "User '${dbUserName}' does not exist yet, creating the user"
  echo "CREATE USER ${dbUserName} WITH PASSWORD '${dbUserPassword}';" > ./create_user.sql
else
  echo "User '${dbUserName}' already exists, updating the password"
  echo "ALTER USER ${dbUserName} WITH PASSWORD '${dbUserPassword}';" > ./create_user.sql
fi

echo "GRANT CONNECT ON DATABASE ${dbName} TO ${dbUserName};">> ./create_user.sql
echo "GRANT USAGE ON SCHEMA public TO ${dbUserName};">> ./create_user.sql
echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${dbUserName};">> ./create_user.sql

echo "User '${dbAdminName}' is running the following user creation script:"
cat ./create_user.sql
psql "${dbConnectionString}" --file=./create_user.sql

echo ""
echo "List of existing users:"
psql "${dbConnectionString}" -tAc "SELECT * FROM pg_roles;"
