FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

ARG AIRFLOW_VERSION=1.10.9
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN apt-get update -yqq && apt-get upgrade -yqq

RUN apt-get install -y python3 python3-pip && \
    ln -s /usr/bin/python3.7 /usr/bin/python && \
    ln -s /usr/bin/pip3 /usr/bin/pip  

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        postgresql \
        jq \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[ldap,crypto,celery,postgres,hive,jdbc,mysql,ssh]==${AIRFLOW_VERSION} \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY script/entrypoint_localexecutor.sh /entrypoint_localexecutor.sh
COPY script/create_db.sh /create_db.sh
COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg
COPY config/postgresql.conf /etc/postgresql/12/main/postgresql.conf
COPY python_modules/ldap_auth_azure.py /usr/local/lib/python3.7/dist-packages/airflow/contrib/auth/backends/
COPY python_modules/sparklivyoperator.py /usr/local/lib/python3.7/dist-packages/airflow/operator/


RUN chown postgres:postgres /etc/postgresql/12/main/postgresql.conf && \
    chmod 750 /etc/postgresql/12/main/postgresql.conf && \
    chown postgres:postgres /create_db.sh && \ 
    chmod 750 /create_db.sh

EXPOSE 8080 5555 8793

WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint_localexecutor.sh"]
