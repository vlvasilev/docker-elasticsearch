#!/bin/sh

# Copyright (c) 2018 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit immediately if command returns a non-zero status
# and print a trace of the command
set -ex


export PATH_DATA=${PATH_DATA:-/data}
# Set environment variables defaults
export ES_JAVA_OPTS=${ES_JAVA_OPTS:-"-Xms512m -Xmx512m"}
export CLUSTER_NAME=${CLUSTER_NAME:-kubernetes-logging}
export NODE_NAME=${NODE_NAME:-${HOSTNAME}}
export NODE_MASTER=${NODE_MASTER:-true}
export NODE_DATA=${NODE_DATA:-true}
export NODE_INGEST=${NODE_INGEST:-true}
export HTTP_ENABLE=${HTTP_ENABLE:-true}
export HTTP_PORT=${HTTP_PORT:-9200}
export TRANSPORT_PORT=${TRANSPORT_PORT:-9300}
export HTTP_CORS_ENABLE=${HTTP_CORS_ENABLE:-true}
export HTTP_CORS_ALLOW_ORIGIN=${HTTP_CORS_ENABLE:-"*"}
export NETWORK_HOST=${NETWORK_HOST:-"_site_"}
export NUMBER_OF_MASTERS=${NUMBER_OF_MASTERS:-1}
export MAX_LOCAL_STORAGE_NODES=${MAX_LOCAL_STORAGE_NODES:-1}
export SHARD_ALLOCATION_AWARENESS=${SHARD_ALLOCATION_AWARENESS:-""}
export SHARD_ALLOCATION_AWARENESS_ATTR=${SHARD_ALLOCATION_AWARENESS_ATTR:-""}
export DISCOVERY_SERVICE=${DISCOVERY_SERVICE:-"elasticsearch-discovery"}
#single node optimization

#10% of the total heap allocated to a node will be used as 
#the indexing buffer size shared across all shards.
export INDEX_BUFFER_SIZE=${INDEX_BUFFER_SIZE:-"10%"}
#adjust the bulk query size
export INDEX_QUEUE_SIZE=${INDEX_QUEUE_SIZE:-200}
#enaable the disk allocation decider.
export ALLOW_DISK_ALLOCATION=${ALLOW_DISK_ALLOCATION:-true}
# Elasticsearch will attempt to relocate shards away from a node whose disk usage is above X%
export DISK_WATERMARK_HIGHT=${DISK_WATERMARK_HIGHT:-"90%"}
 #threshold for read only lock
export DISK_WATERMARK_FLOOD_STAGE=${DISK_WATERMARK_FLOOD_STAGE:-"95%"}

export SHARD_REBALANCING_FOR=${SHARD_REBALANCING_FOR:-"all"}

BASE=/elasticsearch

#TODO conflict
# Set a random node name if not set
if [ -z "${NODE_NAME}" ]; then
    NODE_NAME="$(uuidgen)"
fi

# Set a tem dir name if not set
if [ -z "${ES_TMPDIR}" ]; then
    # Create a temporary folder for Elasticsearch ourselves
    # ref: https://github.com/elastic/elasticsearch/pull/27659
    export ES_TMPDIR="$(mktemp -d -t elasticsearch.XXXXXXXX)"
fi


# Prevent "Text file busy" errors
sync

if [ ! -z "${ES_PLUGINS_INSTALL}" ]; then
    OLDIFS="${IFS}"
    IFS=","
    for plugin in ${ES_PLUGINS_INSTALL}; do
        if ! "${BASE}"/bin/elasticsearch-plugin list | grep -qs ${plugin}; then
            until "${BASE}"/bin/elasticsearch-plugin install --batch ${plugin}; do
                echo "Failed to install ${plugin}, retrying in 3s"
                sleep 3
            done
        fi
    done
    IFS="${OLDIFS}"
fi

#TODO waht is this for
if [ ! -z "${SHARD_ALLOCATION_AWARENESS_ATTR}" ]; then
    # this will map to a file like  /etc/hostname => /dockerhostname so reading that file will get the
    #  container hostname
    if [ -f "${SHARD_ALLOCATION_AWARENESS_ATTR}" ]; then
        ES_SHARD_ATTR="$(cat "${SHARD_ALLOCATION_AWARENESS_ATTR}")"
    else
        ES_SHARD_ATTR="${SHARD_ALLOCATION_AWARENESS_ATTR}"
    fi

    NODE_NAME="${ES_SHARD_ATTR}-${NODE_NAME}"
    echo "node.attr.${SHARD_ALLOCATION_AWARENESS}: ${ES_SHARD_ATTR}" >> $BASE/config/elasticsearch.yml

    if [ "$NODE_MASTER" == "true" ]; then
        echo "cluster.routing.allocation.awareness.attributes: ${SHARD_ALLOCATION_AWARENESS}" >> "${BASE}"/config/elasticsearch.yml
    fi
fi

export NODE_NAME=${NODE_NAME}

# remove x-pack-ml module
rm -rf /elasticsearch/modules/x-pack/x-pack-ml
rm -rf /elasticsearch/modules/x-pack-ml

# Run
if [[ $(whoami) == "root" ]]; then
    if [ ! -d "/data/data/nodes/0" ]; then
        echo "Changing ownership of /data folder"
        chown -R elasticsearch:elasticsearch /data
    fi
    exec su elasticsearch -c /usr/local/bin/docker-entrypoint.sh $ES_EXTRA_ARGS
else
    # The container's first process is not running as 'root', 
    # it does not have the rights to chown. However, we may
    # assume that it is being ran as 'elasticsearch', and that
    # the volumes already have the right permissions. This is
    # the case for Kubernetes, for example, when 'runAsUser: 1000'
    # and 'fsGroup:100' are defined in the pod's security context.
    /usr/local/bin/docker-entrypoint.sh ${ES_EXTRA_ARGS}
fi
