# Airflow LocalExecutor

Airflow Local Executor Docker Distribution

### Features
- Default Local Executor based distribution.
- Posrgres database DB used.
- Dedicated directory (i.e. /usr/local/airflow/volume) which will contains all persistent data,
  thus if Airflow need to persist data over container restart then mount persistent disk for this directory.
- Custom authentication module provided than can work with Active Directory (LDAP and LDAPS) and perform simple
  group (non nested) based access to Airflow UI and set any of the role Superuser, Data Profiler or Unauthenticated.
- Default Self signed certificate based TSL security to Airflow UI.
- Sample custom operator to run Apache Spark Job using Livy.


### Introduction LocalExecutor



### Build



### Execution



