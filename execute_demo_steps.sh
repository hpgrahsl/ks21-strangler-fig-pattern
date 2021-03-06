#!/bin/sh

echo "INFO: running containers:"
docker ps --format "table {{.Names}}"

read -p "INFO: configuring the microservice read path step by step"

echo "STEP 1: change proxy config to route owner reads to microservice"

./proxy_config.sh read

read -p "STEP 2: register MySQL source connector for owners + pets tables"

http POST http://localhost:8083/connectors/ < register-mysql-source-owners-pets.json

read -p "INFO: inspect owners data in kafka"

docker run --tty --rm \
    --network ks21-strangler-fig-pattern_default \
    debezium/tooling:1.1 \
    kafkacat -b kafka:9092 -C -t mysql1.petclinic.owners -o beginning -q | jq .

read -p "INFO: inspect pets data in kafka"

docker run --tty --rm \
    --network ks21-strangler-fig-pattern_default \
    debezium/tooling:1.1 \
    kafkacat -b kafka:9092 -C -t mysql1.petclinic.pets -o beginning -q | jq .

read -p "INFO: inspect kstreams joined data in kafka"

docker run --tty --rm \
    --network ks21-strangler-fig-pattern_default \
    debezium/tooling:1.1 \
    kafkacat -b kafka:9092 -C -t kstreams.owners-with-pets -o beginning -q | jq .

read -p "STEP 3: register MongoDB sink connector for pre-joined owners with pets topic"

http POST http://localhost:8083/connectors/ < register-mongodb-sink-owners-pets.json

echo "INFO: configuring the microservice write path step by step"

read -p "STEP 4: change proxy config to route owner writes to microservice"

./proxy_config.sh read_write

read -p "STEP 5: update MySQL source connector to ignore owner table"

http PUT http://localhost:8083/connectors/petclinic-owners-pets-mysql-src-001/config < update-mysql-source-owners-pets.json

read -p "STEP 6: configure MongoDB source connector for owners with pets collection"
http POST http://localhost:8083/connectors/ < register-mongodb-source-owners.json

echo  "STEP 7: configure MySQL JDBC sink connector for owners table"
http POST http://localhost:8083/connectors/ < register-jdbc-mysql-sink-owners.json

read -p "Done :-)"
