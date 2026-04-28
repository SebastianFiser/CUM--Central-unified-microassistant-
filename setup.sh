#!/bin/bash
echo "enter details of your HiveMQ cluster to setup core to device connection"
read -p "hiveMQ URL: " HIVEMQ_HOST
read -p "hiveMQ port: " HIVEMQ_PORT
read -p "hiveMQ Websocket port: " HIVEMQ_WEBSOCKET_PORT
read -p "hiveMQ username: " HIVEMQ_USERNAME
read -p "hiveMQ password: " HIVEMQ_PASSWORD
echo 

cat > .env << EOF
HIVEMQ_HOST=$HIVEMQ_HOST
HIVEMQ_PORT=$HIVEMQ_PORT
HIVEMQ_USERNAME=$HIVEMQ_USERNAME
HIVEMQ_PASSWORD=$HIVEMQ_PASSWORD
EOF

echo".env file created with the provided HiveMQ cluster details"