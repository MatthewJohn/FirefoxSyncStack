FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt install curl nodejs npm git postfix \
            memcached redis mysql-server \
            graphicsmagick libssl1.0-dev pkg-config \
            mysql-client libmysqlclient-dev nginx \
            libffi-dev g++ python2.7 python-pip python-virtualenv \
            build-essential libmysqlclient-dev libxslt1.1 libxml2 libxml2-dev libxslt1-dev \
            wget openjdk-8-jre-headless \
            --assume-yes
# Not installed for syncserver
# libstdc++
# openssl-dev
RUN npm install -g grunt-cli grunt


# Install Rust
RUN sh <(curl https://sh.rustup.rs -sSf) -y

# Build failure with 'unresolved import `core::ffi::c_void`'
#rustup default nightly
#rustup update && cargo update
COPY environ.sh /environ.sh


# Install local SQS
cd /
git clone https://github.com/adamw/elasticmq
cd /elasticmq
wget https://s3-eu-west-1.amazonaws.com/softwaremill-public/elasticmq-server-0.14.6.jar


# Install basket
RUN . /environ.sh; cd /; git clone https://github.com/mozmeao/basket; \
    cd /basket; f_python_ssl; virtualenv .; . ./bin/activate; \
    pip install --require-hashes --no-cache-dir -r requirements/prod.txt; \
    sed -i 's/ storage_engine=InnoDB/ default_storage_engine=InnoDB/g' /basket/basket/settings.py; \
    deactivate


# Install basket-proxy
RUN cd /; git clone https://github.com/mozilla/fxa-basket-proxy; \
    cd /fxa-basket-proxy; f_python_ssl; npm install


# Install pushbox
RUN cd /; git clone https://github.com/mozilla-services/pushbox; \
  cd /pushbox; f_rust_ssl; (cargo build || true)
#rm rust-toolchain
#sed -i 's/^edition/#edition/g' /root/.cargo/registry/src/github.com*/atoi-0.2.4/Cargo.toml


# Install fxa-email-service
RUN cd /; git clone https://github.com/mozilla/fxa-email-service; \
    cd /fxa-email-service; f_rust_ssl; cargo build


# Install browser ID
RUN cd /; git clone https://github.com/mozilla/browserid-verifier.git; \
    cd /browserid-verifier; f_python_ssl; npm install


# Install fxa-content-server
RUN cd /; git clone https://github.com/mozilla/fxa-content-server; \
    cd /fxa-content-server; f_python_ssl; \
    npm install npm@6 webpack@4.16.1 --global; \
    /usr/local/bin/npm install --production; \
    ./scripts/download_l10n.sh; \
    /usr/local/bin/npm run build-production
#npm install bluebird
#grunt install
#grunt server:dist


# Install fxa-auth-server
RUN cd /; git clone https://github.com/mozilla/fxa-auth-server.git; \
    cd /fxa-auth-server; f_python_ssl; npm install; \
    bash scripts/download_l10n.sh


# Install fxa-auth-db-mysql
RUN cd /; git clone https://github.com/mozilla/fxa-auth-db-mysql; \
    f_python_ssl; npm install


# Install fxa-profile-server
RUN cd /; git clone https://github.com/mozilla/fxa-profile-server; \
    cd /fxa-profile-server; f_python_ssl; npm install; \
    sed -i '/process.env.NODE_ENV/d' scripts/run_dev.js
#sed -i "s/throw new Error('config.events must be included in prod');/logger.warn('');/g" lib/events.js


# Install fxa-customs-server
RUN cd /; git clone https://github.com/mozilla/fxa-customs-server; \
    cd /fxa-customs-server; f_python_ssl; npm install


# Install syncto
RUN cd /; git clone https://github.com/mozilla-services/syncto.git; \
    cd /synctol; f_python_ssl; virtualenv .; \
    . ./bin/activate; \
    sed -i 's/cryptography==.*/cryptography/g' ./requirements.txt; \
    sed -i 's/cffi==.*/cffi/g' ./requirements.txt; \
    sed -i 's/idna==.*/cffi/g' ./requirements.txt; \
    pip install -r ./requirements.txt; \
    rm -rf /syncto/local/lib/python2.7/site-packages/OpenSSL; \
    python ./setup.py build; \
    python ./setup.py install; \
    deactivate


# Install syncserver
RUN cd /; git clone https://github.com/mozilla-services/syncserver; \
    cd /syncserver; f_python_ssl; \
    virtualenv .; . ./bin/virtualenv; \
    make; local/bin/pip install gunicorn; deactivate
# Upgrade of pip breaks it on ubuntu-18.04 (apparently)
#pip install --upgrade pip
#pip install --upgrade --no-cache-dir -r requirements.txt
# pip install --upgrade --no-cache-dir -r dev-requirements.txt

COPY ./setup.sh /

ENV BASE_DOMAIN
RUN /setup.sh

VOLUME /var/lib/mysql

EXPOSE 80
ENTRYPOINT ["/start_all.sh"]
