#!/bin/sh
printenv
flask db init
flask db migrate -m "Initial migration."
flask db upgrade
music_page
