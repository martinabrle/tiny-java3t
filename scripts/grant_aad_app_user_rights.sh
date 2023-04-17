#/bin/sh
Help()
{
   # Display Help
   echo "grant_aad_app_user_rights.sh - utility for granting users CONNECT, USAGE, SELECT, INSERT,"
   echo "                               UPDATE and DELETE privileges on the target database (w AAD)."
   echo ""
   echo "Syntax: grant_aad_app_user_rights.sh [-h|s|d|a|n]"
   echo "options:"
   echo "h     Print this Help."
   echo "s     PGSQL server name"
   echo "d     Database name"
   echo "a     AAD Admin's user name"
   echo "n     App user's name"
   echo
}

# Get the options
dbServerName=""
dbName=""
dbAADAdminName=""
dbUserName=""
while getopts ":h:s:d:a:n::" OPT; do
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

echo "dbServerName: '${dbServerName}'"
echo "dbName: '${dbName}'"
echo "dbAADAdminName: '${dbAADAdminName}'"
echo "dbUserName: '${dbUserName}'"

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
if [[ -z "${dbUserName}" ]]; then
  echo "Error: App database user's name is empty"
  Help
  exit 1
fi


dbUserExists=`psql --set=sslmode=require -h ${dbServerName}.postgres.database.azure.com -p 5432 -d ${dbName} -U "${dbAADAdminName}"  -tAc "SELECT 1 FROM pg_roles WHERE rolname='${dbUserName}';" -v ON_ERROR_STOP=1`

echo "GRANT CONNECT ON DATABASE ${dbName} TO ${dbUserName};" > ./assign_privileges.sql
echo "GRANT USAGE ON SCHEMA public TO ${dbUserName};" >> ./assign_privileges.sql
echo "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${dbUserName};" >> ./assign_privileges.sql
echo " " >> ./assign_privileges.sql

echo "User '${dbAADAdminName}' is assigning privileges using this script:"
cat  ./assign_privileges.sql

psql --set=sslmode=require -h ${{secrets.AZURE_DB_SERVER_NAME}}.postgres.database.azure.com -p 5432 -d ${{secrets.AZURE_DB_NAME}} -U "${{secrets.AZURE_DBA_GROUP_NAME}}" --file=./assign_privileges.sql -v ON_ERROR_STOP=1

echo ""
echo "List of existing users:"
psql --set=sslmode=require -h ${{secrets.AZURE_DB_SERVER_NAME}}.postgres.database.azure.com -p 5432 -d ${{secrets.AZURE_DB_NAME}} -U "${{secrets.AZURE_DBA_GROUP_NAME}}" -tAc "SELECT * FROM pg_roles;" -v ON_ERROR_STOP=1

