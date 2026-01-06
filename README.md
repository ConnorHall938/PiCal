# PiCal
Electronic calendar ran from a raspberry pi

# Building

There is a build script in ./image_build that will create a complete image that is ready to flash onto a raspberry pi
The script will ask for WiFi credentials, as well as some credentials and hostname for an SQL database server.

# Deploying

Take the resulting image from the build section and flash it to an SD card. Put this card into your pi and it should just work!

# Architecture

## Database

There should exist some database server somewhere, probably postgres, with a schema created that will belong to this application.

The application will connect, and create any necessary tables

## Backend

There is a backend server, hosted on the target Pi of the calendar. It will serve a webui and an API

The webui is what is displayed on the calendar screen, and is also available online.

The API will respond to requests, taking and replying with json.

## Frontend

TBD, probably react or some shit idk

# Local running

make -> Production, builds for production.
Run with ./bin/server

make dev Runs a development server, The go API serving it's api and a previously built frontend.
The vite server will serve an up to date frontend, which has hot reload.