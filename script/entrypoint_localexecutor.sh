#!/bin/bash
# Airflow Local Executor: Container Entrypoint
# Version: 1.0.0

# Secret (POSTGRES DB and FERNET KEY) Configuration
if [ -z "${POSTGRES_PASSWORD}" ]
then
  echo "WARN: POSTGRES_PASSWORD not set"
  POSTGRES_PASSWORD="airflow"
fi
FERNET_KEY=$(python -c "import os, base64; from cryptography.hazmat.primitives import hashes; from cryptography.hazmat.backends import default_backend; digest = hashes.Hash(hashes.SHA256(), backend=default_backend()); password = os.getenv('POSTGRES_PASSWORD'); digest.update(password.encode()); print(base64.urlsafe_b64encode(digest.finalize()))")

# Airflow Environment
export AIRFLOW_HOME="/usr/local/airflow"
export AIRFLOW_CORE_SQL_ALCHEMY_CONN="postgresql+psycopg2://airflow:${POSTGRES_PASSWORD}@localhost:5432/airflow"
export AIRFLOW_CORE_EXECUTOR="LocalExecutor"
export AIRFLOW_CORE_FERNET_KEY="${FERNET_KEY}"

# Setting up persistant data storage if not mounted
VOLUME_HOME=/usr/local/airflow/volume
[ ! -d ${VOLUME_HOME} ] && mkdir -p ${VOLUME_HOME}

# Logging
LOG_HOME=${VOLUME_HOME}/logs
export AIRFLOW_CORE_BASE_LOG_FOLDER=${LOG_HOME}
export AIRFLOW_CORE_DAG_PROCESSOR_MANAGER_LOG_LOCATION=${LOG_HOME}/dag_processor_manager/dag_processor_manager.log
export AIRFLOW_SCHEDULER_CHILD_PROCESS_LOG_DIRECTORY=${LOG_HOME}/scheduler

# Setup Database Server
if [ -d ${VOLUME_HOME}/db/main ]
then
  echo "INFO: Database already exists."
  ls -ltr ${VOLUME_HOME}/db/main
else
  [ -d ${VOLUME_HOME}/db ] && rm -rf ${VOLUME_HOME}/db
  mkdir -p ${VOLUME_HOME}/db
  if [ $? -ne 0 ]
  then
    echo "ERROR: Failed to create DB Home"
    exit 1
  else
    cp -r /var/lib/postgresql/12/main ${VOLUME_HOME}/db/
    if [ $? -ne 0 ]
    then
      echo "ERROR: Failed to get default DB configurations"
      exit 1
    else
      echo "INFO: Successfully configured a default DB Server"
    fi
  fi
fi

# Setting DB Home Permission
chown postgres:postgres ${VOLUME_HOME}/db/main
if [ $? -ne 0 ]
then
  echo "ERROR: Failed to set default DB ownership"
  exit 1
fi
chown -R 700 ${VOLUME_HOME}/db/main
if [ $? -ne 0 ]
then
  echo "ERROR: Failed to set default DB permission"
  exit 1
fi 

# Start DB
service postgresql start

# Wait
sleep 5s

# Validate DB startup
service postgresql status
if [ $? -ne 0 ]
then
  echo "ERROR: Failed to start DB"
  exit 1
fi

# Configure DB if not
su - postgres -c 'psql -lqt | cut -d \| -f 1 | grep -qw airflow'
if [ $? -ne 0 ]
then
  echo "NOTICE: DB was not configured, starting to configure DB"
  su - postgres -c "sh /create_db.sh ${POSTGRES_PASSWORD}"
  if [ $? -ne 0 ]
  then
    echo "ERROR: Failed to create and configure DB airflow"
    exit 1
  fi
  airflow initdb
  if [ $? -ne 0 ]
  then
    echo "ERROR: Failed Airflow DB Initialization"
    exit 1
  fi
fi

# Starting Scheduler
airflow scheduler &

# Starting Webserver
airflow webserver
