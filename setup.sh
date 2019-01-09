
# Other Projects
# https://github.com/mozilla-services/loop-server.git
# https://github.com/mozilla/fxa-local-dev

set -e
set +x

apt-get update
apt install curl nodejs npm git postfix \
            memcached redis mysql-server \
            graphicsmagick libssl1.0-dev pkg-config \
            mysql-client libmysqlclient-dev nginx \
            libffi-dev g++ python2.7 python-pip python-virtualenv \
            --assume-yes
# Not installed for syncserver
# libstdc++
# openssl-dev
npm install -g grunt-cli grunt

# Install Rust
sh <(curl https://sh.rustup.rs -sSf) -y
export PATH=$PATH:$HOME/.cargo/bin
source $HOME/.cargo/env
# Build failure with 'unresolved import `core::ffi::c_void`'
#rustup default nightly
#rustup update && cargo update

export MYSQL_USER=root
export MYSQL_PASSWORD=
export BASE_DOMAIN=ff.dockstudios.co.uk
export PUSHBOX_ROCKET_TOKEN=$(openssl rand -base64 32)
export MAIl_ROCKET_TOKEN=$(openssl rand -base64 32)


cd /
git clone https://github.com/mozilla-services/pushbox
cd pushbox
#rm rust-toolchain
cat > /pushbox/Rocket.toml <<EOF
[production]
## Database DSN URL.
database_url="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/pushbox"
## used by FxA OAuth token authorization.
fxa_host="oauth.${BASE_DOMAIN}"
## set "dryrun" to "true" to skip ANY authorization checks.
#dryrun=false
## used by the FXA Server key authorization
server_token="changeme"
[global.limits]
# Maximum accepted data size for JSON payloads.
json = 1048576
EOF
cargo run || true
#sed -i 's/^edition/#edition/g' /root/.cargo/registry/src/github.com*/atoi-0.2.4/Cargo.toml



cd /
git clone https://github.com/mozilla/fxa-email-service
cd /fxa-email-service
rm /fxa-email-service/config/dev.json
cat > /fxa-email-service/config/default.json <<EOF
{
  "authdb": {
    "baseuri": "http://auth.${BASE_DOMAIN}/"
  },
  "aws": {
    "region": "eu-west-1"
  },
  "deliveryproblemlimits": {
    "enabled": true,
    "complaint": [
      { "period": "day", "limit": 0 },
      { "period": "year", "limit": 1 }
    ],
    "hard": [
      { "period": "day", "limit": 0 },
      { "period": "year", "limit": 1 }
    ],
    "soft": [
      { "period": "5 minutes", "limit": 0 }
    ]
  },
  "hmackey": "changeme",
  "host": "127.0.0.1",
  "log": {
    "level": "off",
    "format": "mozlog"
  },
  "port": 8001,
  "provider": {
    "default": "smtp",
    "forcedefault": true
  },
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  },
  "secretkey": "${MAIl_ROCKET_TOKEN}",
  "sender": {
    "address": "accounts@${BASE_DOMAIN}",
    "name": "Firefox Accounts"
  },
  "smtp": {
    "host": "127.0.0.1",
    "port": 25
  }
}
EOF




cd /
git clone git://github.com/mozilla/fxa-auth-server.git
cd /fxa-auth-server
npm install
bash scripts/download_l10n.sh
cat > /fxa-auth-server/config/prod.json <<EOF
{
  "contentServer": {
    "url": "http://127.0.0.1:3030"
  },
  "customsUrl": "none",
  "lockoutEnabled": true,
  "log": {
    "fmt": "pretty",
    "level": "info"
  },
  "sms": {
    "isStatusGeoEnabled": false,
    "useMock": true
  },
  "smtp": {
    "host": "127.0.0.1",
    "port": 25,
    "secure": false,
    "redirectDomain": "api.${BASE_DOMAIN}"
  },
  "securityHistory": {
    "ipProfiling": {
      "allowedRecency": 0
    }
  },
  "lastAccessTimeUpdates": {
    "enabled": true,
    "sampleRate": 1
  },
  "pushbox": {
    "enabled": true,
    "url": "http://localhost:8002/",
    "key": "${ROCKET_TOKEN}",
    "maxTTL": "28 days"
  },
  "metrics": {
    "flow_id_expiry": 7200000,
    "flow_id_key": "wibble"
  },
  "oauth": {
     "clientIds": {},
     "url": "https://oauth.${BASE_DOMAIN}",
     "secretKey": "changeme",
     "keepAlive": false
   }
}
EOF
NODE_ENV=prod node ./scripts/gen_keys.js
NODE_ENV=prod node ./fxa-oauth-server/scripts/gen_keys.js
NODE_ENV=prod node ./scripts/gen_vapid_keys.js










cd /
git clone https://github.com/mozilla/fxa-content-server
cd /fxa-content-server
npm install npm@6 webpack@4.16.1 --global
/usr/local/bin/npm install --production
#npm install bluebird
./scripts/download_l10n.sh
/usr/local/bin/npm run build-production
#grunt install
#grunt server:dist
cat > /fxa-content-server/server/config/production.json <<EOF
{
  "public_url": "https://${BASE_DOMAIN}",
  "oauth_client_id": "98e6508e88680e1a",
  "oauth_url": "https://oauth.${BASE_DOMAIN}",
  "profile_url": "https://profile.${BASE_DOMAIN}",
  "profile_images_url": "https://static.profile.${BASE_DOMAIN}",
  "marketing_email": {
    "api_url": "http://127.0.0.1:1114",
    "preferences_url": "http://localhost:1115"
  },
  "fxaccount_url": "https://api.${BASE_DOMAIN}",
  "geodb": {
    "enabled": false
  },
  basket: {
    api_key: 'changeme',
    api_url: 'http://127.0.0.1:10140',
    proxy_url: 'http://127.0.0.1:1114'
  },
  "sync_tokenserver_url": "https://sync.${BASE_DOMAIN}",
  "client_sessions": {
    "cookie_name": "session",
    "secret": "changeme",
    "duration": 86400000
  },
  "env": "production",
  "use_https": false,
  "static_max_age" : 0,
  "route_log_format": "dev_fxa",
  "logging": {
    "fmt": "pretty",
    "level": "debug"
  },
  "scopedKeys": {
    "enabled": true
  },
  "allowed_metrics_flow_cors_origins": ["https://mail.${BASE_DOMAIN}"],
  "allowed_parent_origins": ["https://${BASE_DOMAIN}"],
  "static_directory": "dist",
  "page_template_subdirectory": "dist",
  "csp": {
    "enabled": true,
    "reportOnly": true
  }
}
EOF










cd /
git clone https://github.com/mozilla/fxa-auth-db-mysql
cd /fxa-auth-db-mysql
npm install
cat > /fxa-auth-db-mysql/config/index.js <<EOF

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

module.exports = function (fs, path, url, convict) {

  var conf = convict({
    env: {
      doc: 'The current node.js environment',
      default: 'prod',
      format: [ 'dev', 'test', 'stage', 'prod' ],
      env: 'NODE_ENV',
    },
    hostname: {
      doc: 'The IP address the server should bind to',
      default: '127.0.0.1',
      env: 'HOST',
    },
    port: {
      doc: 'The port the server should bind to',
      default: 8080,
      format: 'port',
      env: 'PORT',
    },
    logging: {
      app: {
        default: 'fxa-auth-db-server'
      },
      fmt: {
        format: ['heka', 'pretty'],
        default: 'heka'
      },
      level: {
        env: 'LOG_LEVEL',
        default: 'info'
      },
      uncaught: {
        format: ['exit', 'log', 'ignore'],
        default: 'exit'
      }
    },
    patchKey: {
      doc: 'The name of the row in the dbMetadata table which stores the patch level',
      default: 'schema-patch-level',
      env: 'SCHEMA_PATCH_KEY',
    },
    enablePruning: {
      doc: 'Enables (true) or disables (false) pruning',
      default: false,
      format: Boolean,
      env: 'ENABLE_PRUNING',
    },
    pruneEvery: {
      doc: 'Approximate time between prunes (in ms)',
      default: '1 hour',
      format: 'duration',
      env: 'PRUNE_EVERY',
    },
    pruneTokensMaxAge: {
      // This setting must always be older than token lifetimes in the fxa-auth-server
      doc: 'Time after which to prune account, password and unblock tokens (in ms)',
      default: '3 months',
      format: 'duration',
      env: 'PRUNE_TOKENS_MAX_AGE',
    },
    signinCodesMaxAge: {
      doc: 'Maximum age for signinCodes, after which they will expire',
      default: '2 days',
      format: 'duration',
      env: 'SIGNIN_CODES_MAX_AGE',
    },
    requiredSQLModes: {
      doc: 'Comma-separated list of SQL mode flags to enforce on each connection',
      default: '',
      format: 'String',
      env: 'REQUIRED_SQL_MODES',
    },
    master: {
      user: {
        doc: 'The user to connect to for MySql',
        default: 'root',
        env: 'MYSQL_USER',
      },
      password: {
        doc: 'The password to connect to for MySql',
        default: '',
        env: 'MYSQL_PASSWORD',
      },
      host: {
        doc: 'The host to connect to for MySql',
        default: 'localhost',
        env: 'MYSQL_HOST',
      },
      port: {
        doc: 'The port to connect to for MySql',
        default: 3306,
        format: 'port',
        env: 'MYSQL_PORT',
      },
      connectionLimit: {
        doc: 'The maximum number of connections to create at once.',
        default: 10,
        format: 'nat',
        env: 'MYSQL_CONNECTION_LIMIT',
      },
      waitForConnections: {
        doc: "Determines the pool's action when no connections are available and the limit has been reached.",
        default: true,
        format: Boolean,
        env: 'MYSQL_WAIT_FOR_CONNECTIONS',
      },
      queueLimit: {
        doc: "Determines the maximum size of the pool's waiting-for-connections queue.",
        default: 100,
        format: 'nat',
        env: 'MYSQL_QUEUE_LIMIT',
      },
    },
    slave: {
      user: {
        doc: 'The user to connect to for MySql',
        default: 'root',
        env: 'MYSQL_SLAVE_USER',
      },
      password: {
        doc: 'The password to connect to for MySql',
        default: '',
        env: 'MYSQL_SLAVE_PASSWORD',
      },
      host: {
        doc: 'The host to connect to for MySql',
        default: '127.0.0.1',
        env: 'MYSQL_SLAVE_HOST',
      },
      port: {
        doc: 'The port to connect to for MySql',
        default: 3306,
        format: 'port',
        env: 'MYSQL_SLAVE_PORT',
      },
      connectionLimit: {
        doc: 'The maximum number of connections to create at once.',
        default: 10,
        format: 'nat',
        env: 'MYSQL_SLAVE_CONNECTION_LIMIT',
      },
      waitForConnections: {
        doc: "Determines the pool's action when no connections are available and the limit has been reached.",
        default: true,
        format: Boolean,
        env: 'MYSQL_SLAVE_WAIT_FOR_CONNECTIONS',
      },
      queueLimit: {
        doc: "Determines the maximum size of the pool's waiting-for-connections queue.",
        default: 100,
        format: 'nat',
        env: 'MYSQL_SLAVE_QUEUE_LIMIT',
      },
    },
    ipHmacKey: {
      doc: 'A secret to hash IP addresses for security history events',
      default: 'changeme',
      env: 'IP_HMAC_KEY'
    },
    sentryDsn: {
      doc: 'Sentry DSN for error and log reporting',
      default: '',
      format: 'String',
      env: 'SENTRY_DSN'
    },
    recoveryCodes: {
      length: {
        doc: 'The length of a recovery code',
        default: 10,
        format: 'nat',
        env: 'RECOVERY_CODE_LENGTH'
      }
    }
  })

  // handle configuration files. you can specify a CSV list of configuration
  // files to process, which will be overlayed in order, in the CONFIG_FILES
  // environment variable. By default, the ./config/<env>.json file is loaded.

  var envConfig = path.join(__dirname, conf.get('env') + '.json')
  envConfig = envConfig + ',' + process.env.CONFIG_FILES

  var files = envConfig.split(',').filter(fs.existsSync)
  conf.loadFile(files)
  conf.validate({ allowed: 'strict' })

  return conf.getProperties()
}
EOF
node bin/db_patcher.js









cd /
git clone https://github.com/mozilla/fxa-profile-server
cd fxa-profile-server
npm install
sed -i '/process.env.NODE_ENV/d' scripts/run_dev.js
sed -i "s/throw new Error('config.events must be included in prod');/logger.warn('');/g" lib/events.js

cat > /fxa-profile-server/config/production.json <<EOF
{
  "env": "production",
  "logging": {
    "fmt": "pretty",
    "level": "all",
    "debug": true
  },
  "db": {
    "driver": "mysql"
  },
  "img": {
    "driver": "local"
  },
  "customsUrl": "https://profile.${BASE_DOMAIN}/a/{id}",
  "serverCache": {
    "useRedis": true
  },
  "authServer": {
    "url":"https://api.${BASE_DOMAIN}/v1"
  },
  "mysql":{
     "createSchema":true,
     "user":"${MYSQL_USER}",
     "password":"${MYSQL_PASSWORD}",
     "database":"fxa_profile",
     "host":"localhost",
     "port":"3306"
  },
  "oauth":{
     "url":"https://oauth.${BASE_DOMAIN}"
  },
  "publicUrl":"https://profile.${BASE_DOMAIN}",
  "server":{
     "host":"127.0.0.1",
     "port":1111
  },
  "worker":{
     "host":"127.0.0.1",
     "port":1113,
     "url":"http://127.0.0.1:1113"
  },
  "serverCache":{
     "redis":{
        "host":"127.0.0.1",
        "keyPrefix":"fxa-profile",
        "port":6379
     },
     "useRedis":true,
     "expiresIn":3600000,
     "generateTimeout":11000
  }
}
EOF


cd /
git clone https://github.com/mozilla-services/syncserver
cd /syncserver
# Upgrade of pip breaks it on ubuntu-18.04 (apparently)
#pip install --upgrade pip
#pip install --upgrade --no-cache-dir -r requirements.txt
# pip install --upgrade --no-cache-dir -r dev-requirements.txt
make
export SYNCSERVER_SECRET=$(head -c 20 /dev/urandom | sha1sum)
cat > /syncserver/syncserver.ini <<EOF
[server:main]
use = egg:gunicorn
host = 127.0.0.1
port = 5000
workers = 1
timeout = 30

[app:main]
use = egg:syncserver

[syncserver]
# This must be edited to point to the public URL of your server,
# i.e. the URL as seen by Firefox.
public_url = https://sync.${BASE_DOMAIN}/

# By default, syncserver will accept identity assertions issued by
# any BrowserID issuer.  The below restricts it to accept assertions
# from just the production Firefox Account servers.  If you are hosting
# your own account server, put its public URL here instead.
identity_provider = https://${BASE_DOMAIN}/

# This defines the database in which to store all server data.
#sqluri = sqlite:////tmp/syncserver.db
sqluri = pymysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/sync

# This is a secret key used for signing authentication tokens.
# It should be long and randomly-generated.
# The following command will give a suitable value on *nix systems:
#
#    head -c 20 /dev/urandom | sha1sum
#
# If not specified then the server will generate a temporary one at startup.
secret = ${SYNCSERVER_SECRET}

# Set this to "false" to disable new-user signups on the server.
# Only requests by existing accounts will be honoured.
allow_new_users = true

# Set this to "true" to work around a mismatch between public_url and
# the application URL as seen by python, which can happen in certain reverse-
# proxy hosting setups.  It will overwrite the WSGI environ dict with the
# details from public_url.  This could have security implications if e.g.
# you tell the app that it's on HTTPS but it's really on HTTP, so it should
# only be used as a last resort and after careful checking of server config.
force_wsgi_environ = true
EOF


cat > /etc/nginx/sites-enabled/default <<EOF
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	server_name _;

	location / {
    rewrite ^.*\$ https://${BASE_DOMAIN} redirect;
	}
}

server {
	listen 443 default_server;
	listen [::]:443 default_server;

	server_name _;

  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

	location / {
    rewrite ^.*\$ https://${BASE_DOMAIN} redirect;
	}
}

server {
  listen 443 ssl;
  server_name sync.${BASE_DOMAIN};

  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

  location / {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_read_timeout 120;
    proxy_connect_timeout 10;
    proxy_pass http://127.0.0.1:5000/;
   }
}
server {
  listen 443 ssl;
  server_name api.${BASE_DOMAIN};

  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

  location / {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_read_timeout 120;
    proxy_connect_timeout 10;
    proxy_pass http://127.0.0.1:9000/;
   }
}
server {
  listen 443 ssl;
  server_name ${BASE_DOMAIN};

  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

  location / {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_read_timeout 120;
    proxy_connect_timeout 10;
    proxy_pass http://127.0.0.1:3030/;
   }
}
EOF

docker cp  /fxa-auth-server/config/index.js
docker cp /fxa-content-server/server/config/local.json
docker cp /fxa-auth-db-mysql/config/config.js


volumes /var/lib/mysql


service mysql start
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;" | mysql
echo 'CREATE DATABASE pushbox' | mysql
service memcached start
redis-server &
service postfix start

# Ports
# 8002 - pushbox
# 8080 - auth server (api.${BASE_DOMAIN})
# 3030 - account content (${BASE_DOMAIN})
# 3080 - account redirect (?)
# 1111 - profile (profile.${BASE_DOMAIN})
# 1112 - profile static - TBC (??)
# 8001 - email (? None?)
# 5000 - syncserver (sync.${BASE_DOMAIN}) (syncstorage and tokenserver)

# domains
# accounts.${BASE_DOMAIN} - fxa-auth-server
# profile.${BASE_DOMAIN}
# static.profile.${BASE_DOMAIN}
# oath.${BASE_DOMAIN}
# mail.${BASE_DOMAIN}
# content.${BASE_DOMAIN}
# sync.${BASE_DOMAIN}

pushd /pushbox; ROCKET_ENV=production ROCKET_PORT=8002 ROCKET_DATABASE_URL="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/pushbox" cargo run & popd
pushd /fxa-email-service; ROCKET_ENV=production ROCKET_TOKEN=${PUSHBOX_ROCKET_TOKEN} cargo r --bin fxa_email_send & popd
pushd /fxa-auth-db-mysql; NODE_ENV=prod npm start & popd
pushd /fxa-auth-server; NODE_ENV=prod node ./node_modules/fxa-customs-server/bin/customs_server.js & NODE_ENV=prod scripts/start-server.sh & popd
pushd /fxa-content-server; NODE_ENV=production npm run start-production & popd
pushd /fxa-profile-server; NODE_ENV=production npm start & popd
pushd /syncserver; gunicorn --bind 127.0.0.1:5000 \
                            --forwarded-allow-ips="127.0.0.1,172.17.0.1" \
                            --paste /syncserver/syncserver.ini \
                              syncserver.wsgi_app & popd
