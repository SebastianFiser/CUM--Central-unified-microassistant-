#!/bin/bash
echo "enter details of your HiveMQ cluster to setup core to device connection"
read -p "hiveMQ URL: " HIVEMQ_HOST
read -p "hiveMQ port: " HIVEMQ_PORT
read -p "hiveMQ Websocket port: " HIVEMQ_WEBSOCKET_PORT
read -p "hiveMQ username: " HIVEMQ_USERNAME
read -p "hiveMQ password: " HIVEMQ_PASSWORD
read -p "Hivemq ws URL: " HIVEMQ_WS_URL
echo 

cat > .env << EOF
HIVEMQ_HOST=$HIVEMQ_HOST
HIVEMQ_PORT=$HIVEMQ_PORT
HIVEMQ_WEBSOCKET_PORT=$HIVEMQ_WEBSOCKET_PORT
HIVEMQ_USERNAME=$HIVEMQ_USERNAME
HIVEMQ_PASSWORD=$HIVEMQ_PASSWORD
HIVEMQ_WS_URL=$HIVEMQ_WS_URL
EOF

echo "copying into app folder"
cp .env android_app/.env
echo "copied .env"

echo ".env file created with the provided HiveMQ cluster details"