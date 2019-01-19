#!/bin/bash

# Other Projects
# https://github.com/mozilla-services/loop-server.git
# https://github.com/mozilla/fxa-local-dev
# https://github.com/michielbdejong/fxa-self-hosting
# fxa-oauth-client

set -e
set +x



cat > /settings_include.sh <<EOF
export MYSQL_USER=root
export MYSQL_PASSWORD=
export BASE_DOMAIN=${BASE_DOMAIN}
export PUSHBOX_ROCKET_TOKEN=$(openssl rand -base64 32)
export MAIl_ROCKET_TOKEN=$(openssl rand -base64 32)
export BASKET_SECRET_KEY=$(openssl rand -base64 32)
export ENABLE_GEODB="false"
export FLOW_HMAC_KEY=$(openssl rand -base64 32)
export EMAIL_HMAC_KEY=$(openssl rand -base64 32)
export OAUTH_SECRET=$(openssl rand -base64 32)

# CONTENT SERVER
export CONTENT_INTERNAL_HOST=127.0.0.1
export CONTENT_INTERNAL_PORT=3030
export CONTENT_INTERNAL_URL=http://\${CONTENT_INTERNAL_HOST}:\${CONTENT_INTERNAL_PORT}
export CONTENT_EXTERNAL_DOMAIN=\${BASE_DOMAIN}
export CONTENT_EXTERNAL_URL=https://\${CONTENT_EXTERNAL_DOMAIN}
# AUTH (API) SERVER
export AUTH_INTERNAL_HOST=127.0.0.1
export AUTH_INTERNAL_PORT=9000
export AUTH_INTERNAL_URL=http://\${AUTH_INTERNAL_HOST}:\${AUTH_INTERNAL_PORT}
export AUTH_EXTERNAL_DOMAIN=api.\${BASE_DOMAIN}
export AUTH_EXTERNAL_URL=https://\${AUTH_EXTERNAL_DOMAIN}

export OAUTH_INTERNAL_HOST=127.0.0.1
export OAUTH_INTERNAL_PORT=9010
export OAUTH_INTERNAL_URL=http://\${OAUTH_INTERNAL_HOST}:\${OAUTH_INTERNAL_PORT}
export OAUTH_EXTERNAL_DOMAIN=oauth.\${BASE_DOMAIN}
export OAUTH_EXTERNAL_URL=https://\${OAUTH_EXTERNAL_DOMAIN}


export PROFILE_INTERNAL_HOST=127.0.0.1
export PROFILE_INTERNAL_PORT=1111
export PROFILE_INTERNAL_URL=http://\${PROFILE_INTERNAL_HOST}:\${PROFILE_INTERNAL_PORT}
export PROFILE_EXTERNAL_URL=https://profile.\${BASE_DOMAIN}
export STATIC_PROFILE_INTERNAL_HOST=127.0.0.1
export STATIC_PROFILE_INTERNAL_PORT=1112
export STATIC_PROFILE_INTERNAL_URL=http://\${STATIC_PROFILE_INTERNAL_HOST}:\${STATIC_PROFILE_INTERNAL_PORT}
export STATIC_PROFILE_EXTERNAL_URL=https://static.profile.\${BASE_DOMAIN}

export SYNC_INTERNAL_HOST=127.0.0.1
export SYNC_INTERNAL_PORT=5000
export SYNC_INTERNAL_URL=http://\${SYNC_INTERNAL_HOST}:\${SYNC_INTERNAL_PORT}
export SYNC_EXTERNAL_URL=https://sync.\${BASE_DOMAIN}

export AUTH_DB_INTERNAL_HOST=127.0.0.1
export AUTH_DB_INTERNAL_PORT=8080
export AUTH_DB_INTERNAL_URL=http://\${AUTH_DB_INTERNAL_HOST}:\${AUTH_DB_INTERNAL_PORT}

export PUSHBOX_INTERNAL_HOST=127.0.0.1
export PUSHBOX_INTERNAL_PORT=8002
export PUSHBOX_INTERNAL_URL=http://\${PUSHBOX_INTERNAL_HOST}:\${PUSHBOX_INTERNAL_PORT}/

export BROWSERID_VERIFIER_HOST=127.0.0.1
export BROWSERID_VERIFIER_PORT=5050
export BROWSERID_VERIFIER_INTERNAL_URL=http://\${BROWSERID_VERIFIER_HOST}:\${BROWSERID_VERIFIER_PORT}
export BROWSERID_VERIFIER_EXTERNAL_URL=https://verifier.\${BASE_DOMAIN}

export SYNCTO_HOST=127.0.0.1
export SYNCTO_PORT=8005
export SYNCTO_INTERNAL_URL=http://\${SYNCTO_HOST}:\${SYNCTO_PORT}
export SYNCTO_TOKEN=$(tr -dc 'A-F0-9' < /dev/urandom | head -c32)

export TOKEN_EXTERNAL_URL=\${SYNC_EXTERNAL_URL}/token

export CUSTOMS_INTERNAL_URL=http://127.0.0.1:7000

export BASKET_INTERNAL_HOST=127.0.0.1
export BASKET_INTERNAL_PORT=10140
export BASKET_INTERNAL_URL=http://\${BASKET_INTERNAL_HOST}:\${BASKET_INTERNAL_PORT}
export BASKET_EXTERNAL_DOMAIN=basket.\${BASE_DOMAIN}
export BASKET_EXTERNAL_URL=https://\${BASKET_PROXY_EXTERNAL_DOMAIN}

export BASKET_PROXY_INTERNAL_HOST=127.0.0.1
export BASKET_PROXY_INTERNAL_PORT=1114
export BASKET_PROXY_INTERNAL_URL=http://\${BASKET_PROXY_INTERNAL_HOST}:\${BASKET_PROXY_INTERNAL_PORT}
export BASKET_PROXY_EXTERNAL_DOMAIN=\${CONTENT_EXTERNAL_DOMAIN}
export BASKET_PROXY_EXTERNAL_URL=https://\${BASKET_PROXY_EXTERNAL_DOMAIN}/basket


export SQS_HOSTNAME=127.0.0.1
export SQS_PORT=9324
export SQS_BASE_URL=http://\${SQS_HOSTNAME}:\${SQS_PORT}
export BASKET_SQS_QUEUE_URL=\${SQS_BASE_URL}/queue/basket
export PUSHBOX_SQS_QUEUE_URL=\${SQS_BASE_URL}/queue/pushbox
export PROFILE_UPDATES_SQS_QUEUE_URL=\${SQS_BASE_URL}/queue/profile-updates
export ACCOUNT_EVENTS_SQS_QUEUE_URL=\${SQS_BASE_URL}/queue/account-events
export AWS_ACCESS_KEY_ID=forlocal
export AWS_SECRET_ACCESS_KEY=sqsinstance
EOF
. /settings_include.sh











cd /elasticmq
cat > /elasticmq/custom.conf <<EOF
include classpath("application.conf")

// What is the outside visible address of this ElasticMQ node
// Used to create the queue URL (may be different from bind address!)
node-address {
    protocol = http
    host = "${SQS_HOSTNAME}"
    port = ${SQS_PORT}
    context-path = ""
}

rest-sqs {
    enabled = true
    bind-port = ${SQS_PORT}
    bind-hostname = "${SQS_HOSTNAME}"
    // Possible values: relaxed, strict
    sqs-limits = relaxed
}

// Should the node-address be generated from the bind port/hostname
// Set this to true e.g. when assigning port automatically by using port 0.
generate-node-address = false

queues {
    // See next section
    basket {
        defaultVisibilityTimeout = 10 seconds
        delay = 0 seconds
        receiveMessageWait = 0 seconds
        deadLettersQueue {
            name = "queue1-dead-letters"
            maxReceiveCount = 3 // from 1 to 1000
        }
        fifo = false
        contentBasedDeduplication = false
        //copyTo = "audit-queue-name"
        //moveTo = "redirect-queue-name"
        //tags {
        //    tag1 = "tagged1"
        //    tag2 = "tagged2"
        //}
    }
    pushbox {
        defaultVisibilityTimeout = 10 seconds
        delay = 0 seconds
        receiveMessageWait = 0 seconds
        fifo = false
        contentBasedDeduplication = false
    }
    profile-updates {
        defaultVisibilityTimeout = 10 seconds
        delay = 0 seconds
        receiveMessageWait = 0 seconds
        fifo = false
        contentBasedDeduplication = false
    }
    account-events {
        defaultVisibilityTimeout = 10 seconds
        delay = 0 seconds
        receiveMessageWait = 0 seconds
        fifo = false
        contentBasedDeduplication = false
    }
    queue1-dead-letters { }
    audit-queue-name { }
    redirect-queue-name { }
}

EOF








service mysql restart
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;" | mysql
echo 'CREATE DATABASE pushbox' | mysql
echo 'CREATE DATABASE sync' | mysql
echo 'CREATE DATABASE basket' | mysql
service memcached restart
redis-server &
service postfix restart








cd /basket
. ./bin/activate
DEBUG=False SECRET_KEY=${BASKET_SECRET_KEY} ALLOWED_HOSTS=localhost, DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/basket \
    ./manage.py collectstatic --noinput
SECRET_KEY=${BASKET_SECRET_KEY} DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/basket ./manage.py migrate
export BASKET_API_KEY=$(echo 'from basket.news.models import APIUser; ff = APIUser(name="Firefox"); ff.save(); print ff.api_key' | DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/basket SECRET_KEY=${BASKET_SECRET_KEY} ./manage.py shell)
echo "export BASKET_API_KEY=${BASKET_API_KEY}" >> /settings_include.sh
deactivate
. /settings_include.sh








cd /fxa-basket-proxy
cat > /fxa-basket-proxy/config/production.json <<EOF
{
  "env": "production",
  "basket": {
    "api_url": "${BASKET_INTERNAL_URL}/news",
    "proxy_url": "${BASKET_PROXY_INTERNAL_URL}",
    "api_key": "${BASKET_API_KEY}",
    "source_url": "${CONTENT_EXTERNAL_URL}",
    "sqs": {
      "queue_url": "${BASKET_SQS_QUEUE_URL}",
      "region": "elasticmq"
    }
  },
  "fxaccount_url": "${AUTH_INTERNAL_URL}",
  "oauth_url": "${OAUTH_INTERNAL_URL}",
  "log": {
    "format": "heka"
  }
}
EOF
# cat > /fxa-basket-proxy/node_modules/aws-sdk/lib/region_config_data.json <<EOF
# {
#   "rules": {
#     "*/*": {
#       "endpoint": "127.0.0.1"
#     }
#   }
# }
# EOF
















cd /pushbox
cat > /pushbox/Rocket.toml <<EOF
[production]
## Database DSN URL.
database_url="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/pushbox"
## used by FxA OAuth token authorization.
fxa_host="${OAUTH_EXTERNAL_DOMAIN}"
## set "dryrun" to "true" to skip ANY authorization checks.
#dryrun=false
## used by the FXA Server key authorization
server_token="${PUSHBOX_ROCKET_TOKEN}"
sqs_url="${PUSHBOX_SQS_QUEUE_URL}"
[global.limits]
# Maximum accepted data size for JSON payloads.
json = 1048576
EOF











# Configure fx-email-service
cd /fxa-email-service
rm /fxa-email-service/config/dev.json
cat > /fxa-email-service/config/default.json <<EOF
{
  "authdb": {
    "baseuri": "${AUTH_DB_INTERNAL_URL}/"
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
  "hmackey": "${EMAIL_HMAC_KEY}",
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














cd /fxa-auth-server
cat > /fxa-auth-server/config/prod.json <<EOF
{
  "contentServer": {
    "url": "${CONTENT_EXTERNAL_URL}"
  },
  "publicUrl": "${AUTH_EXTERNAL_URL}",
  "domain": "${AUTH_EXTERNAL_URL}",
  "customsUrl": "${CUSTOMS_INTERNAL_URL}/a/{id}",
  "lockoutEnabled": true,
  "log": {
    "fmt": "pretty",
    "level": "info"
  },
  "sms": {
    "enabled": false,
    "isStatusGeoEnabled": false,
    "useMock": true
  },
  "httpdb": {
    "url": "${AUTH_DB_INTERNAL_URL}/"
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
  "geodb": {
    "enabled": ${ENABLE_GEODB}
  },
  "lastAccessTimeUpdates": {
    "enabled": true,
    "sampleRate": 1
  },
  "pushbox": {
    "enabled": true,
    "url": "${PUSHBOX_INTERNAL_URL}",
    "key": "${ROCKET_TOKEN}",
    "maxTTL": "28 days"
  },
  "metrics": {
    "flow_id_expiry": 7200000,
    "flow_id_key": "${FLOW_HMAC_KEY}"
  },
  "oauth": {
     "clientIds": {},
     "url": "${OAUTH_INTERNAL_URL}",
     "secretKey": "${OAUTH_SECRET}",
     "keepAlive": false
   },
   "profileServerMessaging": {
    "profileUpdatesQueueUrl": "${PROFILE_UPDATES_SQS_QUEUE_URL}",
    "region": "elasticmq"
   },
   "snsTopicArn": "disabled"
}
EOF
cat > /fxa-auth-server/fxa-oauth-server/config/prod.json <<EOF
{
  "server": {
    "host": "127.0.0.1",
    "port": 9010
  },
  "serverInternal": {
    "host": "127.0.0.1",
    "port": 9011
  },
  "clientManagement": {
    "enabled": true
  },
  "events": {
    "queueUrl": "${ACCOUNT_EVENTS_SQS_QUEUE_URL}",
    "region": "elasticmq"
  },
  "clients": [
    {
      "id": "98e6508e88680e1a",
      "hashedSecret": "ba5cfb370fd782f7eae1807443ab816288c101a54c0d80a09063273c86d3c435",
      "name": "Firefox Accounts Settings",
      "imageUri": "https://${BASE_DOMAIN}/logo",
      "redirectUri": "${CONTENTEXTERNAL_URL}/",
      "trusted": true,
      "canGrant": true
    }
  ],
  "logging": {
    "level": "error",
    "fmt": "pretty"
  },
  "openid": {
    "keyFile": "../config/key.json",
    "oldKeyFile": "../config/oldKey.json",
    "key": {},
    "oldKey": {},
    "issuer": "${CONTENT_EXTERNAL_URL}"
  },
  "allowHttpRedirects": true,
  "authServerSecrets": ["${OAUTH_SECRET}"],
  "publicUrl": "${OAUTH_EXTERNAL_URL}",
  "server": {
    "host": "${OAUTH_INTERNAL_HOST}",
    "port": "${OAUTH_INTERNAL_PORT}"
  },
  "db": {
    "driver": "mysql"
  },
  "browserid": {
    "issuer": "${AUTH_EXTERNAL_DOMAIN}",
    "verificationUrl": "${BROWSERID_VERIFIER_INTERNAL_URL}/v2"
  },
  "contentUrl": "${CONTENT_EXTERNAL_URL}/oauth/",
  "admin": {
    "whitelist": ["@dockstudios.co.uk\$"]
  },
  "mysql": {
    "createSchema": true,
    "user": "${MYSQL_USER}",
    "password": "${MYSQL_PASSWORD}",
    "host": "localhost",
    "database": "fxa_oauth"
  },
  "scopes": []
}
EOF
NODE_ENV=prod node ./scripts/gen_keys.js
NODE_ENV=prod node ./fxa-oauth-server/scripts/gen_keys.js
NODE_ENV=prod node ./scripts/gen_vapid_keys.js














cd /browserid-verifier
cat > /browserid-verifier/config/production.json <<EOF
{
    "logging": {
        "handlers": {
            "console": {
                "class": "intel/handlers/console",
                "formatter": "json"
            }
        },
        "loggers": {
            "bid.summary": {
                "propagate": true
            }
        }
    },
    "insecureSSL": true,
    "port": ${BROWSERID_VERIFIER_PORT},
    "ip": "${BROWSERID_VERIFIER_HOST}"
}
EOF
















cd /fxa-content-server
rm /fxa-content-server/server/config/local.json
rm /fxa-content-server/server/config/fxaci.json
cat > /fxa-content-server/server/config/production.json <<EOF
{
  "public_url": "${CONTENT_EXTERNAL_URL}",
  "oauth_client_id": "98e6508e88680e1a",
  "oauth_url": "${OAUTH_EXTERNAL_URL}",
  "profile_url": "${PROFILE_EXTERNAL_URL}",
  "profile_images_url": "${STATIC_PROFILE_EXTERNAL_URL}",
  "fxaccount_url": "${AUTH_EXTERNAL_URL}",
  "marketing_email": {
    "api_url": "${BASKET_PROXY_EXTERNAL_URL}",
    "preferences_url": "http://localhost:1115"
  },
  "flow_id_key": "${FLOW_HMAC_KEY}",
  "geodb": {
    "enabled": ${ENABLE_GEODB}
  },
  "basket": {
    "api_key": "${BASKET_API_KEY}",
    "api_url": "${BASKET_INTERNAL_URL}",
    "proxy_url": "${BASKET_PROXY_EXTERNAL_URL}"
  },
  "sync_tokenserver_url": "https://sync.${BASE_DOMAIN}/token",
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
  "allowed_metrics_flow_cors_origins": ["https://${BASE_DOMAIN}"],
  "allowed_parent_origins": ["https://${BASE_DOMAIN}"],
  "static_directory": "dist",
  "page_template_subdirectory": "dist",
  "csp": {
    "enabled": true,
    "reportOnly": true
  }
}
EOF










cd /fxa-auth-db-mysql
node bin/db_patcher.js
cat > /fxa-auth-db-mysql/config/config.js <<EOF

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
      default: '${AUTH_DB_INTERNAL_HOST}',
      env: 'HOST',
    },
    port: {
      doc: 'The port the server should bind to',
      default: ${AUTH_DB_INTERNAL_PORT},
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










cd /fxa-profile-server
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
    "driver": "local",
    "url": "${CONTENT_EXTERNAL_URL}/a/{id}",
    "providers": {
      "fxa": "^${CONTENT_EXTERNAL_URL}/a/[0-9a-f]{32}\$"
    }
  },
  "customsUrl": "${CUSTOMS_INTERNAL_URL}/a/{id}",
  "serverCache": {
    "useRedis": true
  },
  "authServer": {
    "url":"${AUTH_INTERNAL_URL}/v1"
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
     "url":"${OAUTH_INTERNAL_URL}/v1"
  },
  "publicUrl":"${PROFILE_EXTERNAL_URL}",
  "server":{
     "host":"${PROFILE_INTERNAL_HOST}",
     "port":${PROFILE_INTERNAL_PORT}
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
  },
  "events": {
    "queueUrl": "${ACCOUNT_EVENTS_SQS_QUEUE_URL}",
    "region": "elasticmq"
  },
  "authServerMessaging": {
    "profileUpdatesQueueUrl": "${PROFILE_UPDATES_SQS_QUEUE_URL}",
    "region": "elasticmq"
  }
}
EOF








cd /syncto
cat > /syncto/config/production.ini <<EOF
[app:main]
use = egg:syncto

syncto.record_history_put_enabled = true
syncto.record_history_delete_enabled = true

syncto.cache_backend = cliquet.cache.redis
syncto.cache_url = redis://localhost:6379/1
syncto.http_scheme = http
syncto.http_host = ${SYNCTO_HOST}
syncto.retry_after_seconds = 30
syncto.batch_max_requests = 25
syncto.cache_hmac_secret = ${SYNCTO_TOKEN}
syncto.token_server_url = ${TOKEN_EXTERNAL_URL}/


[server:main]
use = egg:waitress#main
host = 0.0.0.0
port = ${SYNCTO_PORT}

EOF



cd /syncserver
export SYNCSERVER_SECRET=$(head -c 20 /dev/urandom | sha1sum | awk '{ print $1 }')
cat > /syncserver/syncserver.ini <<EOF
[server:main]
use = egg:gunicorn
host = ${SYNC_INTERNAL_HOST}
port = ${SYNC_INTERNAL_PORT}
workers = 1
timeout = 60

[app:main]
use = egg:syncserver

[syncserver]
# This must be edited to point to the public URL of your server,
# i.e. the URL as seen by Firefox.
public_url = ${SYNC_EXTERNAL_URL}/

# By default, syncserver will accept identity assertions issued by
# any BrowserID issuer.  The below restricts it to accept assertions
# from just the production Firefox Account servers.  If you are hosting
# your own account server, put its public URL here instead.
#identity_provider = ${CONTENT_EXTERNAL_URL}/
identity_provider = ${CONTENT_INTERNAL_URL}/

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

forwarded_allow_ips = *
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

  large_client_header_buffers 4 8k;

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
    proxy_pass ${AUTH_INTERNAL_URL}/;
   }
}
server {
  listen 443 ssl;
  server_name basket.${BASE_DOMAIN};

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
    proxy_pass ${BASKET_INTERNAL_URL}/;
   }
}

server {
  listen 443 ssl;
  server_name verifier.${BASE_DOMAIN};

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
    proxy_pass ${BROWSERID_VERIFIER_INTERNAL_URL}/;
   }
}
server {
  listen 443 ssl;
  server_name oauth.${BASE_DOMAIN};

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
    proxy_pass ${OAUTH_INTERNAL_URL}/;
   }
}
server {
  listen 443 ssl;
  server_name profile.${BASE_DOMAIN};

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
    proxy_pass ${PROFILE_INTERNAL_URL}/;
   }
}
server {
  listen 443 ssl;
  server_name ${BASE_DOMAIN};

  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

  location /basket/ {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_read_timeout 120;
    proxy_connect_timeout 10;
    #rewrite ^/lookup-user/(.*) /lookup-user\$1;
    proxy_pass ${BASKET_PROXY_INTERNAL_URL}/;
   }
  location / {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_read_timeout 120;
    proxy_connect_timeout 10;
    proxy_pass ${CONTENT_INTERNAL_URL}/;
   }
}
EOF

#docker cp  /fxa-auth-server/config/index.js
#docker cp /fxa-content-server/server/config/local.json
#docker cp /fxa-auth-db-mysql/config/config.js


#volumes /var/lib/mysql

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

cat > /start_all.sh <<'EOF'
#!/bin/bash

redis-server &
service nginx restart
service memcached restart
service mysql restart
service postfix restart
. /settings_include.sh

export PATH=$PATH:$HOME/.cargo/bin
source $HOME/.cargo/env

pushd /elasticmq; java -Dconfig.file=custom.conf -jar elasticmq-server-0.14.6.jar & popd
pushd /pushbox; AWS_LOCAL_SQS=${SQS_BASE_URL} ROCKET_ENV=production ROCKET_PORT=${PUSHBOX_INTERNAL_PORT} ROCKET_DATABASE_URL="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/pushbox" cargo run & popd
pushd /browserid-verifier; NODE_ENV=production CONFIG_FILES=config/production.json node /browserid-verifier/server.js & popd;
pushd /fxa-email-service; ROCKET_ENV=production ROCKET_TOKEN=${PUSHBOX_ROCKET_TOKEN} cargo r --bin fxa_email_send & popd
pushd /fxa-auth-db-mysql; NODE_ENV=prod npm start & popd
pushd /fxa-customs-server; NODE_ENV=prod node /fxa-customs-server/bin/customs_server.js & popd
pushd /fxa-auth-server; NODE_ENV=prod /fxa-auth-server/scripts/start-server.sh & popd
pushd /fxa-auth-server/fxa-oauth-server; NODE_ENV=prod node /fxa-auth-server/fxa-oauth-server/bin/server.js & popd

pushd /fxa-content-server; NODE_ENV=production npm run start-production & popd
pushd /fxa-profile-server; NODE_ENV=production npm start & popd

pushd /fxa-basket-proxy; NODE_ENV=production CONFIG_FILES=config/production.json node /fxa-basket-proxy/bin/basket-event-handler.js &
                         NODE_ENV=production CONFIG_FILES=config/production.json node bin/basket-proxy-server.js & popd


# pushd /syncto; . ./bin/activate; gunicorn --bind ${SYNCTO_HOST}:${SYNCTO_PORT} \
#                                                   --forwarded-allow-ips="127.0.0.1,172.17.0.1" \
#                                                   --paste /syncto/config/production.ini \
#                                                     app.wsgi & deactivate; popd

pushd /syncto; . ./bin/activate;
  python /syncto/lib/python2.7/site-packages/cliquet/scripts/cliquet.py --ini /syncto/config/production.ini migrate;
  python /syncto/local/lib/python2.7/site-packages/pyramid/scripts/pserve.py /syncto/config/production.ini --reload & deactivate; popd


pushd /basket; . ./bin/activate;
  SECRET_KEY=${BASKET_SECRET_KEY} DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@localhost/basket ALLOWED_HOSTS=${BASKET_EXTERNAL_DOMAIN},${CONTENT_EXTERNAL_DOMAIN},127.0.0.1 gunicorn basket.wsgi \
    --bind "${BASKET_INTERNAL_HOST}:${BASKET_INTERNAL_PORT}" \
    --workers "${WSGI_NUM_WORKERS:-8}" \
    --worker-class "${WSGI_WORKER_CLASS:-meinheld.gmeinheld.MeinheldWorker}" \
    --log-level "${WSGI_LOG_LEVEL:-info}" \
    --error-logfile - \
    --access-logfile - &
  #SECRET_KEY=${BASKET_SECRET_KEY} ./bin/run-clock.sh &
  #SECRET_KEY=${BASKET_SECRET_KEY} ./bin/run-donate-worker.sh &
  #SECRET_KEY=${BASKET_SECRET_KEY} ./bin/run-fxa-activity-worker.sh &
  #SECRET_KEY=${BASKET_SECRET_KEY} ./bin/run-fxa-events-worker.sh &
  #SECRET_KEY=${BASKET_SECRET_KEY} ./bin/run-worker.sh &
deactivate; popd

pushd /syncserver; . ./bin/activate; /syncserver/local/bin/gunicorn --bind ${SYNC_INTERNAL_HOST}:${SYNC_INTERNAL_PORT} \
                                                  --forwarded-allow-ips="127.0.0.1,172.17.0.1" \
                                                  --paste /syncserver/syncserver.ini \
                                                    syncserver.wsgi_app & deactivate; popd

while true
do
  sleep 30
done

EOF
chmod +x /start_all.sh
