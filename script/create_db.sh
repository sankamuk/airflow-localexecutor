echo "Starting airflow DB configuration script"
DBPASS=$1

if [ -z "${DBPASS}" ]
then
  echo "ERROR: Script need DB password as only argument"
  exit 1
fi

echo "INFO: Starting to create airflow database"
psql -c "create database airflow"
if [ $? -ne 0 ]
then
  echo "ERROR: Database creation failed"
  exit 1
fi

echo "INFO: Creating user and setting password"
psql -c "create user airflow with encrypted password '${DBPASS}'"
if [ $? -ne 0 ]
then
  echo "ERROR: Database user creation failed"
  exit 1
fi

echo "INFO: Granting user access to database"
psql -c "grant all privileges on database airflow to airflow"
if [ $? -ne 0 ]
then
  echo "ERROR: Database user autorisation setup failed"
  exit 1
fi

echo "INFO: Completed airflow DB setup"
