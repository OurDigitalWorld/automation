#!/bin/bash

# Synopsis
#
# - Build with Ruby 1.9.3-p547, with dpla_frontend_assets gem
#   build_frontend.sh 1.9.3-p547
#
# - Build as above, but without dpla_frontend_assets gem
#   build_frontend.sh 1.9.3-p547 nobranding

# Known issue:
#
# If you run `bundle install --with dpla_branding` and then do
# `bundle install --without dpla_branding`, Bundler will keep trying to fetch
# the dpla_frontend_assets gem when Unicorn is run with `bundle exec`, which
# will result in errors.  We don't know of a way around this yet.  It works fine
# if you start with `--without` and later switch to `--with`.

USE_VERSION=$1
NO_BRANDING=${2:-""}
export PATH=$HOME/.rbenv/bin:$PATH
LOGFILE=/tmp/build_frontend.log

nobranding() {
    if [ "$NO_BRANDING" == "nobranding" ]; then
        return 0
    else
        return 1
    fi
}

echo "starting" > $LOGFILE

eval "`rbenv init -`" >> $LOGFILE 2>&1

if ! nobranding; then
    # Start ssh-agent and set environment variables.
    # Work-around for private GitHub repository in Gemfile.
    eval `ssh-agent`
    ssh-add $HOME/git_private_key  >> $LOGFILE 2>&1
fi

cd $HOME/frontend

rbenv shell $USE_VERSION >> $LOGFILE 2>&1

echo "installing bundle ..." >> $LOGFILE

rm -f Gemfile.lock
if nobranding; then
    install_opts="--without dpla_branding"
else
    install_opts="--with dpla_branding"
fi
echo "install_opts: $install_opts" >> $LOGFILE
bundle install $install_opts >> $LOGFILE 2>&1
rbenv rehash

echo "precompiling assets ..." >> $LOGFILE
bundle exec rake assets:precompile >> $LOGFILE 2>&1

if ! nobranding; then
    echo "killing ssh_agent ..." >> $LOGFILE
    # Variable set above by ssh-agent
    kill $SSH_AGENT_PID
fi

echo "rsync home to /srv/www ..." >> $LOGFILE
/usr/bin/rsync -rIptogl --checksum --delete --delay-updates \
    --exclude 'log' \
    --exclude 'tmp' \
    --exclude '.git' \
    --exclude 'public/uploads' \
    /home/dpla/frontend/ /srv/www/frontend
if [ $? -ne 0 ]; then
    exit 1
fi

echo "migrate database ..." >> $LOGFILE
cd /srv/www/frontend
bundle exec rake db:migrate

echo "check logfile directory ..." >> $LOGFILE

logdir='/srv/www/frontend/log'
if [ ! -d $logdir ]; then
    mkdir $logdir \
        && chown dpla:webapp $logdir \
        && chmod 0775 $logdir
fi
