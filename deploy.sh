#!/bin/bash

FORCE=false
NEW=false
while [ $1 ]
do
  echo $1
  if [ "$1" == "-f" ]; then
    FORCE=true
  fi
  shift
done

BASEPORT=4650
REPO="https://github.com/hogsmill/training-app.git"
MAINAPP="trainingApp"
MAINCOLLECTION="trainingApp"
MAINPEOPLECOLLECTION="trainingAppPeople"
MAINNAME="Training App"
ROUTES=(
  '',''
  'new','New'
)

for ((i = 0; i < ${#ROUTES[@]}; i++))
do
  REC="${ROUTES[$i]}"
  ROUTE=`echo $REC | cut -d, -f1`
  COLLECTIONSUFFIX=`echo $REC | cut -d, -f2`

  APP=$MAINAPP
  if [ "$ROUTE" != "" ]; then
    APP="${APP}-${ROUTE}"
  fi
  COLLECTION=$MAINCOLLECTION
  if [ "$COLLECTIONSUFFIX" != "" ]; then
    COLLECTION="${COLLECTION}${COLLECTIONSUFFIX}"
  fi
  PEOPLECOLLECTION=$MAINPEOPLECOLLECTION
  if [ "$COLLECTIONSUFFIX" != "" ]; then
    PEOPLECOLLECTION="${PEOPLECOLLECTION}${COLLECTIONSUFFIX}"
  fi
  APPNAME=$MAINNAME
  let PORT=$BASEPORT+$i

  echo "------------------------------------------------"
  echo "Installing $APP ($COLLECTION, $PEOPLECOLLECTION, $PORT)"
  echo "------------------------------------------------"

  DIR="/usr/apps/$APP"
  if [ ! -d $DIR ]; then
    git clone $REPO $DIR
  fi
  ENVFILE="$DIR/.env"
  echo "VUE_APP_PORT=$PORT" > $ENVFILE
  echo "VUE_APP_COLLECTION=$COLLECTION" >> $ENVFILE
  echo "VUE_PEOPLE_COLLECTION=$PEOPLECOLLECTION" >> $ENVFILE
  echo "VUE_APP_NAME=$APPNAME" >> $ENVFILE

  cd $DIR

  rm $DIR/package-lock.json
  rm -rf $DIR/node_modules

  PWD=`pwd`
  APP=`basename $PWD`
  git stash
  GIT=`git pull`
  echo $GIT
  if [ "$FORCE" != "true" -a "$GIT" == "Already up to date." ]; then
    exit 0
  fi

  npm install --legacy-peer-deps
  npm run build
  if [ ! -d /var/www/html/$APP/ ]; then
    mkdir /var/www/html/$APP
  fi
  if [ -d /var/www/html/$APP/css ]; then
    rm /var/www/html/$APP/css/*
  else
    mkdir /var/www/html/$APP/css
  fi
  if [ -d /var/www/html/$APP/js ]; then
    rm /var/www/html/$APP/js/*
  else
    mkdir /var/www/html/$APP/js
  fi
  cp -R dist/* /var/www/html/$APP
  if [ -f "src/server.js" ]; then
    SERVER=`ps -ef | grep server.js | grep "/$APP/" | awk {'print $2'}`
    if [ "$SERVER" != "" ]; then
      kill -9 $SERVER
    fi
  fi
  if [ $i == 0 ]; then
    rm -rf $DIR/node_modules/.cache
  else
    rm -rf node_modules
    ln -s ../$MAINAPP/node_modules node_modules
  fi
  rm -rf $DIR/dist
done

ps -ef | grep php | grep outdated
if [ $? -eq 1 ]; then
  php /usr/apps/monitor/src/lib/outdated.php &
fi
