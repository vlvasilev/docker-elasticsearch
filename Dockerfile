FROM docker.elastic.co/elasticsearch/elasticsearch-oss:6.4.2

# Export HTTP & Transport
EXPOSE 9200 9300

#WORKDIR /elasticsearch

# Copy configuration
COPY config /elasticsearch/config

# Copy run script
COPY run.sh bin/

# Volume for Elasticsearch data
VOLUME ["/data"]

CMD ["run.sh"]
