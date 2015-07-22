#!/bin/bash
# ----------------------------------------------------------------------
# Numenta Platform for Intelligent Computing (NuPIC)
# Copyright (C) 2015, Numenta, Inc.  Unless you have purchased from
# Numenta, Inc. a separate commercial license for this software code, the
# following terms and conditions apply:
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# http://numenta.org/licenses/
# ----------------------------------------------------------------------
#

USAGE="Usage: `basename $0`

This script configures a pair of Taurus Server and Metric Collector
instances in which the taurus services are not already running.  For example,
use this to kick off taurus on a fresh instance started with internal numenta
tooling.

☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★

The following environment variables are required to configure a pair of Taurus
instances!

Git commit:

  ☞  COMMIT_SHA

DynamoDB credentials:

  ☞  DYNAMODB_HOST
  ☞  DYNAMODB_PORT
  ☞  DYNAMODB_TABLE_SUFFIX

MySQL credentials:

  ☞  MYSQL_HOST
  ☞  MYSQL_PASSWD
  ☞  MYSQL_USER

RabbitMQ credentials:

  ☞  RABBITMQ_HOST
  ☞  RABBITMQ_PASSWD
  ☞  RABBITMQ_USER

Taurus instance credentials:

  ☞  TAURUS_COLLECTOR_USER
  ☞  TAURUS_COLLECTOR_HOST
  ☞  TAURUS_SERVER_USER
  ☞  TAURUS_SERVER_HOST

AWS credentials
  ☞  AWS_ACCESS_KEY_ID
  ☞  AWS_SECRET_ACCESS_KEY

Taurus Collector configuration details:

  ☞  XIGNITE_API_TOKEN
  ☞  TAURUS_TWITTER_ACCESS_TOKEN
  ☞  TAURUS_TWITTER_ACCESS_TOKEN_SECRET
  ☞  TAURUS_TWITTER_CONSUMER_KEY
  ☞  TAURUS_TWITTER_CONSUMER_SECRET
  ☞  ERROR_REPORT_EMAIL_AWS_REGION
  ☞  ERROR_REPORT_EMAIL_RECIPIENTS
  ☞  ERROR_REPORT_EMAIL_SENDER_ADDRESS
  ☞  ERROR_REPORT_EMAIL_SES_ENDPOINT

Taurus Server configuration details:

  ☞  TAURUS_RMQ_METRIC_DEST
  ☞  TAURUS_RMQ_METRIC_PREFIX
  ☞  TAURUS_API_KEY

☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★ ☆ ★

This script will push the local numenta-apps repository to the remote Taurus
instances, and reset to the commit sha specified in \$COMMIT_SHA.  The
requisite python packages will be installed, configuration commands executed,
and services started.  The end result upon successful completion of this script
(as evidenced by a return code of 0), will be a fully configured, and running
pair of Taurus instances suitable for use and/or testing.
"

if [ "${1}" == "-h" ]; then
  echo "$USAGE"
  exit 0
fi

set -o errexit
set -o pipefail
set -o nounset
set -o verbose

SCRIPT=`which $0`
REPOPATH=`dirname "${SCRIPT}"`/../../..

pushd "${REPOPATH}"

  # Sync git histories with taurus server for current HEAD
  git push --force \
    "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}":/opt/numenta/products \
    `git rev-parse --abbrev-ref HEAD`

  # Reset server state
  ssh -v -t "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}" \
    "cd /opt/numenta/products &&
     git reset --hard ${COMMIT_SHA}"

  # Sync git histories with taurus collector for current HEAD
  git push --force \
    "${TAURUS_COLLECTOR_USER}"@"${TAURUS_COLLECTOR_HOST}":/opt/numenta/products \
    `git rev-parse --abbrev-ref HEAD`

  # Reset server state
  ssh -v -t "${TAURUS_COLLECTOR_USER}"@"${TAURUS_COLLECTOR_HOST}" \
    "cd /opt/numenta/products &&
     git reset --hard ${COMMIT_SHA}"

  # /opt/numenta/products/taurus/conf/ssl must exist before we attempt to
  # upload our self-signed cert required for nginx later
  ssh -v -t "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}" \
    "mkdir -p /opt/numenta/products/taurus/conf/ssl"

  # Generate env.sh credential files, to be copied to respective remote
  # instances later
  echo "
    export PATH=/opt/numenta/anaconda/bin:\$PATH
    export PYTHONPATH=/opt/numenta/anaconda/lib/python2.7/site-packages:\$PYTHONPATH
    export APPLICATION_CONFIG_PATH=/opt/numenta/products/taurus.metric_collectors/conf
    export TAURUS_HTM_SERVER=${TAURUS_SERVER_HOST}
    export XIGNITE_API_TOKEN=${XIGNITE_API_TOKEN}
    export TAURUS_TWITTER_ACCESS_TOKEN=${TAURUS_TWITTER_ACCESS_TOKEN}
    export TAURUS_TWITTER_ACCESS_TOKEN_SECRET=${TAURUS_TWITTER_ACCESS_TOKEN_SECRET}
    export TAURUS_TWITTER_CONSUMER_KEY=${TAURUS_TWITTER_CONSUMER_KEY}
    export TAURUS_TWITTER_CONSUMER_SECRET=${TAURUS_TWITTER_CONSUMER_SECRET}
    export ERROR_REPORT_EMAIL_AWS_REGION=${ERROR_REPORT_EMAIL_AWS_REGION}
    export ERROR_REPORT_EMAIL_RECIPIENTS=${ERROR_REPORT_EMAIL_RECIPIENTS}
    export ERROR_REPORT_EMAIL_SENDER_ADDRESS=${ERROR_REPORT_EMAIL_SENDER_ADDRESS}
    export ERROR_REPORT_EMAIL_SES_ENDPOINT=${ERROR_REPORT_EMAIL_SES_ENDPOINT}
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" | \
    sed -e 's/^[ \t]*//' > \
    taurus/pipeline/scripts/taurus.metric_collectors-env.sh

  echo "
    export PATH=/opt/numenta/anaconda/bin:\$PATH
    export PYTHONPATH=/opt/numenta/anaconda/lib/python2.7/site-packages:\$PYTHONPATH
    export APPLICATION_CONFIG_PATH=/opt/numenta/products/taurus/conf
    export TAURUS_RMQ_METRIC_DEST=${TAURUS_RMQ_METRIC_DEST}
    export TAURUS_RMQ_METRIC_PREFIX=${TAURUS_RMQ_METRIC_PREFIX}
    export TAURUS_API_KEY=${TAURUS_API_KEY}" | \
    sed -e 's/^[ \t]*//' > \
    taurus/pipeline/scripts/taurus-env.sh

  # Copy manual overrides, including ssl self-signed cert
  scp -r \
    taurus/pipeline/scripts/overrides/taurus/* \
    "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}":/opt/numenta/products/taurus/
  scp -r \
    taurus/pipeline/scripts/taurus.metric_collectors-env.sh \
    "${TAURUS_COLLECTOR_USER}"@"${TAURUS_COLLECTOR_HOST}":/opt/numenta/products/taurus.metric_collectors/env.sh
  scp -r \
    taurus/pipeline/scripts/taurus-env.sh \
    "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}":/opt/numenta/products/taurus/env.sh

  # Configure, start Taurus services
  ssh -v -t "${TAURUS_SERVER_USER}"@"${TAURUS_SERVER_HOST}" \
    "cd /opt/numenta/products &&
     ./install-taurus.sh \
        /opt/numenta/anaconda/lib/python2.7/site-packages \
        /opt/numenta/anaconda/bin &&
     taurus-set-rabbitmq \
        --host=127.0.0.1 \
        --user=${RABBITMQ_USER} \
        --password=${RABBITMQ_PASSWD} &&
     taurus-set-sql-login \
        --host=${MYSQL_HOST} \
        --user=${MYSQL_USER} \
        --password=${MYSQL_PASSWD} &&
     taurus-create-db \
        --host=${MYSQL_HOST} \
        --user=${MYSQL_USER} \
        --password=${MYSQL_PASSWD} \
        --suppress-prompt-and-continue-with-deletion &&
     taurus-set-dynamodb \
        --host=${DYNAMODB_HOST} \
        --port=${DYNAMODB_PORT} \
        --table-suffix=${DYNAMODB_TABLE_SUFFIX} &&
     cd /opt/numenta/products/taurus/taurus/engine/repository &&
     python migrate.py &&
     cd /opt/numenta/products/taurus &&
     sudo /usr/sbin/nginx -p . -c conf/nginx-taurus.conf &&
     mkdir -p logs &&
     supervisord -c conf/supervisord.conf"

exit 0;

  # Reset metric collector state, apply database schema updates
  ssh -v -t "${TAURUS_COLLECTOR_USER}"@"${TAURUS_COLLECTOR_HOST}" \
    "cd /opt/numenta/products &&
     git reset --hard ${COMMIT_SHA} &&
     ./install-taurus-metric-collectors.sh \
        /opt/numenta/anaconda/lib/python2.7/site-packages \
        /opt/numenta/anaconda/bin &&
     taurus-set-collectorsdb-login \
        --host=${MYSQL_HOST} \
        --user=${MYSQL_USER} \
        --password=${MYSQL_PASSWD} &&
     taurus-collectors-set-rabbitmq \
        --host=${RABBITMQ_HOST} \
        --user=${RABBITMQ_USER} \
        --password=${RABBITMQ_PASSWD} &&
     taurus-reset-collectorsdb \
        --suppress-prompt-and-obliterate-database &&
     cd /opt/numenta/products/taurus.metric_collectors/taurus/metric_collectors/collectorsdb &&
     python migrate.py &&
     taurus-collectors-set-opmode active &&
     cd /opt/numenta/products/taurus.metric_collectors &&
     supervisord -c conf/supervisord.conf"

popd

echo "Done!"
