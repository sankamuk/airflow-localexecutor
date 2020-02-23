# -*- coding: utf-8 -*-
# Custom operator to submit a Spark Job with Livy

import os
import pathlib
import json
import requests
import codecs
import time
from airflow.exceptions import AirflowException
from airflow.models.baseoperator import BaseOperator
from airflow.utils.decorators import apply_defaults

class LivySubmitOperator(BaseOperator):
  ui_color = '#F4F4F6'

  @apply_defaults
  def __init__(
    self,
    cluster_name,
    livy_job_config,
    user_name,
    user_password,
    timeout=21600,
    *args,
    **kwargs):
    """
    """
    super(LivySubmitOperator, self).__init__(*args, **kwargs)
    self.cluster_name = cluster_name
    self.livy_job_config = livy_job_config
    self.user_name = user_name
    self.user_password = user_password
    self.timeout = timeout
 
  def execute(self, context):
    """
    """
    if len(self.cluster_name) == 0 :
      raise AirflowException('Cluster name not set')
    if len(self.livy_job_config) == 0 :
      raise AirflowException('Livy job config file name not set')
    if len(self.user_name) == 0 :
      raise AirflowException('User name not set')
    if len(self.user_password) == 0 :
      raise AirflowException('User password not set')
    if not ininstance(self.timeout, int) :
      raise AirflowException('Timeout has to be a number')

    # Validate the Job Config file is present in DAGs directory
    config_file = os.path.join(os.environ['AIRFLOW__CORE__DAGS__FOLDER'], self.livy_job_config)
    if not (pathlib.Path(config_file)).is_file() :
      raise AirflowException('Livy job config file {} not present in DAGs directory'.format(self.livy_job_config))

    try :
      with codecs.open(config_file, 'r', encoding='utf8') as file_handle:
        file_content = file_handle.read()
      uri = "https://{}/livy/batches".format(self.cluster_name)
      s = requests.Session()
      s.auth = (self.user_name, self.user_password)
      s.header.update({'Content-Type': 'application/json', 'X-Request-By': 'admin'})

      # Submit Job
      response = s.post(uri, data=file_content)
      if response.status_code != 201 :
        self.log.error('Failed to submit job to Livy successfully, status {}'.format(response.status_code))
        self.log.error(response.text)
        raise AirflowException('Failed to submit job to Livy')
      self.log.info('Successfully submitted job to Livy')
      self.log.debug(response.text)

      response_json = json.loads(response.text)
      session_id = response_json['id']
      self.log.info('Detected session id {}, will wait for batch session to complete'.format(str(session_id)))
      start_time = time.time()

      # Wait until job completion or timeout
      s.header.update({})
      uri = 'https://{0}/livy/batches/{1}'.format(self.cluster_name, str(session_id))
      response = s.get(uri)
      if response.status_code != 200 :
        self.log.error(response.text)
        raise AirflowException('Failed to extract batch session status from Livy')

      while (json.loads(response.text))['state'] not in ['success', 'error', 'dead'] : 
        self.log.info('Current batch session status {} is not completed, thus wait for 30 secons to revalidate'.format(json.loads(response.text))['state']))
        time.sleep(30)
        response = s.get(uri)
        if response.status_code != 200 :
          self.log.error(response.text)
          raise AirflowException('Failed to extract batch session status from Livy')
        if (time.time() - start_time) > self.timeout :
          raise AirflowException('Timeout')
      self.log.info('Batch session completed')
    except Exception as e :
      self.log.error(e)
      raise AirflowException('Failed in batch execution operation')

    if (json.loads(response.text))['state'] == 'success' :
      self.log.info('Completed successfully')
    else :
      raise AirflowException('Batch execution operation completed successfully but job ended with failure')
      
