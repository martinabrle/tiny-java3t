#/bin/sh
Help()
{
   # Display Help
   echo "create_aad_pgsql_user.sh - utility for creating AAD PGSQL users on Azure "
   echo "                          and granting them CONNECT, USAGE, SELECT, INSERT,"
   echo "                          UPDATE and DELETE privileges on the target database."
   echo ""
   echo "Syntax: create_aad_pgsql_user.sh [-h|n|s|d|a|p|n|o]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     PGSQL server name"
   echo "d     Database name"
   echo "a     Admin's user name"
   echo "p     Admin's password"
   echo "n     New user's name"
   echo "o     New user's ObjectId"
   echo
}

# Get the options
dbServerName=""
dbName=""
dbAdminName=""
dbAdminPassword=""
dbUserName=""
dbUserObjectId=""
while getopts ":h:s:d:a:p:n:o:" OPT; do
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
      o) # New user's ObjectId
         dbUserObjectId=$OPTARG
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
if [[ -z "${dbUserObjectId}" ]]; then
  echo "Error: New database user's ObjectId is empty"
  Help
  exit 1
fi

export PGPASSWORD="${dbAdminPassword}"
dbUserExists=`psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d ${dbName} -U "${dbAdminName}"  -tAc "SELECT 1 FROM pg_roles WHERE rolname='${dbUserName}';"`

if [[ $dbUserExists -ne '1' ]]; then
  echo "User '${dbUserName}' does not exist yet, creating the user"
  echo "CREATE USER ${dbUserName} WITH PASSWORD '${dbUserPassword}';" > ./create_user.sql
  echo ""
  echo "User '${dbAdminName}' is running security label assignment script:"
  cat ./create_role.sql
  psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d ${dbName} -U "${dbAdminName}" --file=./create_role.sql
else
  echo "User '${dbUserName}' already exists, skipping the creation"
fi

echo "security label for pgaadauth " > ./security_label.sql
echo "    on role ${dbUserName} " >> ./security_label.sql
echo "    is 'aadauth,oid=${dbUserObjectId},type=service'; " >> ./security_label.sql
echo ""
echo "User '${dbAdminName}' is running security label assignment script:"
cat ./security_label.sql
psql "${dbConnectionString}"  --file=./security_label.sql

echo "GRANT CONNECT ON DATABASE ${dbName} TO ${dbUserName};"> ./grant_rights.sql
echo "GRANT USAGE ON SCHEMA public TO ${dbUserName};">> ./grant_rights.sql
echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${dbUserName};">> ./grant_rights.sql
echo ""
echo "User '${dbAdminName}' is running the following user creation script:"
cat ./grant_rights.sql
psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d ${dbName} -U "${dbAdminName}" --file=./grant_rights.sql

echo ""
echo "List of existing users:"
psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d ${dbName} -U "${dbAdminName}" -tAc "SELECT * FROM pg_roles;"
