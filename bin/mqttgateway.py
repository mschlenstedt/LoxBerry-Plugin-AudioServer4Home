#!/usr/bin/python3
# -*- coding: utf-8 -*-
import websocket
import _thread
import sys
import string
import time
import paho.mqtt.client as mqtt
import json
import logging
import os
import signal
import datetime
import getopt
from queue import Queue
import rel

#############################################################################
# Global vars
#############################################################################

mqttq=Queue()
wsq=Queue()
verbose=0
pconfig = dict()
mqttconfig = dict()
data = dict()
lastsend=0

lbpconfigdir = os.popen("perl -e 'use LoxBerry::System; print $lbpconfigdir; exit;'").read()
lbpdatadir = os.popen("perl -e 'use LoxBerry::System; print $lbpdatadir; exit;'").read()
lbplogdir = os.popen("perl -e 'use LoxBerry::System; print $lbplogdir; exit;'").read()
pluginversion = os.popen("perl -e 'use LoxBerry::System; my $version = LoxBerry::System::pluginversion(); print $version; exit;'").read()

#############################################################################
# MQTT Lib functions
#############################################################################

def mqtt_on_connect(client, userdata, flags, rc):
    if rc==0:
        mqttclient.connected_flag=True #set flag
        log.info("MQTT: Connected OK")
    else:
        log.critical("MQTT: Bad connection, Returned code=",rc)

def mqtt_on_message(client, userdata, message):
    mqttq.put(message)

#############################################################################
# Websocket Lib functions
#############################################################################

def ws_on_message(ws, message):
    wsq.put(message)

def ws_on_error(ws, error):
    log.error("Websocket: Error")

def ws_on_close(ws, close_status_code, close_msg):
    log.info("Websocket: Closed")
    if close_status_code or close_msg:
        log.info("Close status code: " + str(close_status_code))
        log.info("Close message: " + str(close_msg))

def ws_on_open(ws):
    log.info("Websocket: Connected OK")

#############################################################################
# Plugin Lib functions
#############################################################################

def readconfig():
    try:
        with open(lbpconfigdir + '/plugin.json') as f:
            global pconfig
            pconfig = json.load(f)
    except:
        log.critical("Cannot read plugin configuration")
        sys.exit()

def exit_handler(a="", b=""):
    # Close MQTT
    mqttclient.loop_stop()
    log.info("MQTT: Disconnecting from Broker.")
    mqttclient.disconnect()
    # Close Websocket
    wsclient.close()
    # close the log
    if str(logdbkey) != "":
        logging.shutdown()
        os.system("perl -e 'use LoxBerry::Log; my $log = LoxBerry::Log->new ( dbkey => \"" + logdbkey + "\", append => 1 ); LOGEND \"Good Bye.\"; $log->close; exit;'")
    else:
        log.info("Good Bye.")
    # End
    sys.exit();


#############################################################################
# Main Script
#############################################################################

# Standard loglevel
loglevel="ERROR"
logfile=""
logdbkey=""

# Get full command-line arguments
# https://stackabuse.com/command-line-arguments-in-python/
full_cmd_arguments = sys.argv
argument_list = full_cmd_arguments[1:]
short_options = "vlfd:"
long_options = ["verbose","loglevel=","logfile=","logdbkey="]

try:
    arguments, values = getopt.getopt(argument_list, short_options, long_options)
except getopt.error as err:
    print (str(err))
    sys.exit(2)

for current_argument, current_value in arguments:
    if current_argument in ("-v", "--verbose"):
        loglevel="DEBUG"
        verbose=1
    elif current_argument in ("-l", "--loglevel"):
        loglevel=current_value
    elif current_argument in ("-f", "--logfile"):
        logfile=current_value
    elif current_argument in ("-d", "--logdbkey"):
        logdbkey=current_value

# Logging with standard LoxBerry log format
numeric_loglevel = getattr(logging, loglevel.upper(), None)
if not isinstance(numeric_loglevel, int):
    raise ValueError('Invalid log level: %s' % loglevel)

if str(logfile) == "":
    logfile = str(lbplogdir) + "/" + datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')[:-3] + "_mqtt-gateway.log"

log = logging.getLogger()
fileHandler = logging.FileHandler(logfile)
formatter = logging.Formatter('%(asctime)s.%(msecs)03d <%(levelname)s> %(message)s',datefmt='%H:%M:%S')

if verbose == 1:
    streamHandler = logging.StreamHandler(sys.stdout)
    streamHandler.setFormatter(formatter)
    log.addHandler(streamHandler)

fileHandler.setFormatter(formatter)
log.addHandler(fileHandler)

# Logging Starting message
log.setLevel(logging.INFO)
log.info("Starting Logfile for mqtt-gateway. The Loglevel is %s" % loglevel.upper())
log.setLevel(numeric_loglevel)

# Read MQTT config
mqttconfig['server'] = os.popen("perl -e 'use LoxBerry::IO; my $mqttcred = LoxBerry::IO::mqtt_connectiondetails(); print $mqttcred->{brokerhost}; exit'").read()
mqttconfig['port'] = os.popen("perl -e 'use LoxBerry::IO; my $mqttcred = LoxBerry::IO::mqtt_connectiondetails(); print $mqttcred->{brokerport}; exit'").read()
mqttconfig['username'] = os.popen("perl -e 'use LoxBerry::IO; my $mqttcred = LoxBerry::IO::mqtt_connectiondetails(); print $mqttcred->{brokeruser}; exit'").read()
mqttconfig['password'] = os.popen("perl -e 'use LoxBerry::IO; my $mqttcred = LoxBerry::IO::mqtt_connectiondetails(); print $mqttcred->{brokerpass}; exit'").read()

# Read Plugin config
readconfig()

# Conncect to broker
mqttclient = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
mqttclient.connected_flag=False
mqttclient.on_connect = mqtt_on_connect

if mqttconfig['username'] and mqttconfig['password']:
    log.info("Using MQTT Username and password.")
    mqttclient.username_pw_set(username = mqttconfig['username'],password = mqttconfig['password'])

log.info("Connecting to Broker %s on port %s." % (mqttconfig['server'], str(mqttconfig['port'])))
mqttclient.connect(mqttconfig['server'], port = int(mqttconfig['port']))

# Subscription for W4L Topic
#log.info("Subscribe to: " + cfg.get('SERVER','TOPIC') + "/#")
#client.subscribe(cfg.get('SERVER','TOPIC') + "/#", qos=0)
#client.on_message = on_message

# Start MQTT Loop
mqttclient.loop_start()

# Wait for connection
counter=0
while not mqttclient.connected_flag: #wait in loop
    log.info("MQTT: Wait for connection...")
    time.sleep(1)
    counter+=1
    if counter > 60:
        log.critical("MQTT: Cannot connect to Broker %s on port %s." % (mqttconfig['server'], str(mqttconfig['port'])))
        exit()

# COnnect to Websocket
websocket.enableTrace(True)
wsclient = websocket.WebSocketApp(str(pconfig['mass']['protocol']) + "://" + str(pconfig['mass']['host']) + ":" + str(pconfig['mass']['port']) + "/ws",
                          on_open=ws_on_open,
                          on_message=ws_on_message,
                          on_error=ws_on_error,
                          on_close=ws_on_close)

wsclient.run_forever(dispatcher=rel, reconnect=5)  # Set dispatcher to automatic reconnection, 5 second reconnect delay if connection closed unexpectedly
rel.signal(2, rel.abort)  # Keyboard Interrupt
rel.dispatch()

# Exit handler
signal.signal(signal.SIGTERM, exit_handler)
signal.signal(signal.SIGINT, exit_handler)

# Loop
while True:

    # Check for any subscribed mqtt messages in the queue
    while not mqttq.empty():
        message = mqttq.get()
        response = ""

        log.debug("Received subscription: " + str(message.topic) + " Payload: " + str(message.payload.decode("utf-8")))

        if message is None:
            continue

    # Check for any websocket messages in the queue
    while not wsq.empty():
        message = ws.get()
        response = ""

        log.debug("Received Websocket Event: " + str(message.topic) + " Payload: " + str(message.payload.decode("utf-8")))

        if message is None:
            continue

    # Loop
    now = datetime.datetime.now()

    time.sleep(0.1)
