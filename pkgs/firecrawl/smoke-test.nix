{
  writeShellApplication,
  firecrawl,
  postgresql,
  redis,
  rabbitmq-server,
  python3,
  curl,
  jq,
  coreutils,
  procps,
  netcat,
  gnugrep,
  gnused,
}:

writeShellApplication {
  name = "firecrawl-smoke-test";

  runtimeInputs = [
    firecrawl
    postgresql
    redis
    rabbitmq-server
    python3
    curl
    jq
    coreutils
    procps
    netcat
    gnugrep
    gnused
  ];

  text = ''
    set -euo pipefail

    # Configuration
    FIXTURE_PORT=18999
    PG_PORT=15432
    REDIS_PORT=16379
    RMQ_PORT=15673
    API_PORT=13002

    WORKDIR=$(mktemp -d)
    CLEANUP_PIDS=( )

    cleanup() {
      echo "[SMOKE] Cleaning up..."
      # Tidy RabbitMQ first (needs env for node name / port)
      if [ -f "$WORKDIR/rmq-mnesia" ]; then
        RABBITMQ_NODE_PORT=$RMQ_PORT \
        RABBITMQ_NODENAME=firecrawl-smoke@localhost \
          rabbitmqctl stop 2>/dev/null || true
      fi
      kill "''${CLEANUP_PIDS[@]}" 2>/dev/null || true
      if [ -f "$WORKDIR/pgdata/postmaster.pid" ]; then
        pg_ctl -D "$WORKDIR/pgdata" stop -m fast 2>/dev/null || true
      fi
      if [ -f "$WORKDIR/redis.pid" ]; then
        kill "$(cat "$WORKDIR/redis.pid")" 2>/dev/null || true
      fi
      rm -rf "$WORKDIR"
      echo "[SMOKE] Cleanup done."
    }
    trap cleanup EXIT INT TERM

    wait_for_port() {
      local port=$1
      local timeout=''${2:-30}
      local elapsed=0
      while [ "$elapsed" -lt "$timeout" ]; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
          return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
      done
      return 1
    }

    # -- PostgreSQL --
    echo "[SMOKE] Starting PostgreSQL on port $PG_PORT..."
    initdb -D "$WORKDIR/pgdata" --auth=trust --no-locale --encoding=UTF8 --nosync 2>&1 | sed 's/^/[PG] /'
    pg_ctl -D "$WORKDIR/pgdata" -l "$WORKDIR/pg.log" -o "-p $PG_PORT -h 127.0.0.1 -k $WORKDIR" start 2>&1 | sed 's/^/[PG] /'
    wait_for_port $PG_PORT
    echo "[SMOKE] PostgreSQL ready."

    createdb -p $PG_PORT -h 127.0.0.1 firecrawl 2>&1 | sed 's/^/[PG] /' || true

    # Load NUQ schema; filter out pg_cron-dependent lines (pg_cron needs
    # shared_preload_libraries, not available in temp PG).  ALTER SYSTEM
    # lines are skipped too — they modify global config on a transient DB
    # and would only make sense for production tuning.
    NUQ_SQL="${firecrawl}/share/firecrawl/nuq.sql"
    if [ -f "$NUQ_SQL" ]; then
      echo "[SMOKE] Loading NUQ schema (filtered for smoke test)..."
      grep -vE '^(ALTER SYSTEM|CREATE EXTENSION IF NOT EXISTS pg_cron|SELECT pg_reload_conf)' "$NUQ_SQL" \
        | sed '/^SELECT cron\.schedule(/,/\$\$);/d' \
        > "$WORKDIR/nuq_filtered.sql"
      psql -p $PG_PORT -h 127.0.0.1 -d firecrawl -f "$WORKDIR/nuq_filtered.sql" 2>&1 | sed 's/^/[PG] /'
      echo "[SMOKE] NUQ schema loaded."
    else
      echo "[SMOKE] WARNING: nuq.sql not found at $NUQ_SQL, skipping NUQ schema load."
    fi

    # -- Redis --
    echo "[SMOKE] Starting Redis on port $REDIS_PORT..."
    redis-server --port $REDIS_PORT --daemonize yes --pidfile "$WORKDIR/redis.pid" --dir "$WORKDIR" --bind 127.0.0.1 2>&1 | sed 's/^/[REDIS] /'
    wait_for_port $REDIS_PORT
    echo "[SMOKE] Redis ready."

    # -- RabbitMQ --
    echo "[SMOKE] Starting RabbitMQ on port $RMQ_PORT..."
    mkdir -p "$WORKDIR/rmq-mnesia" "$WORKDIR/rmq-logs"
    RABBITMQ_NODE_PORT=$RMQ_PORT \
    RABBITMQ_NODENAME=firecrawl-smoke@localhost \
    RABBITMQ_MNESIA_BASE="$WORKDIR/rmq-mnesia" \
    RABBITMQ_LOG_BASE="$WORKDIR/rmq-logs" \
      rabbitmq-server &
    RMQ_PID=$!
    CLEANUP_PIDS+=("$RMQ_PID")
    wait_for_port $RMQ_PORT
    echo "[SMOKE] RabbitMQ ready."

    # -- HTTP fixture --
    echo "[SMOKE] Starting HTTP fixture on port $FIXTURE_PORT..."
    cat > "$WORKDIR/index.html" << 'FIXTURE_EOF'
    <!DOCTYPE html>
    <html><head><title>Firecrawl Smoke Test</title></head>
    <body><h1>Hello from Firecrawl smoke test</h1>
    <p>This is a test page for validating Firecrawl API health.</p></body></html>
    FIXTURE_EOF

    cd "$WORKDIR"
    python3 -m http.server $FIXTURE_PORT --bind 127.0.0.1 &
    PYTHON_PID=$!
    CLEANUP_PIDS+=("$PYTHON_PID")
    wait_for_port $FIXTURE_PORT
    echo "[SMOKE] HTTP fixture ready."

    # -- Firecrawl (full harness) --
    DATABASE_URL="postgresql:///firecrawl?host=$WORKDIR&port=$PG_PORT"
    NUQ_DATABASE_URL="$DATABASE_URL"
    REDIS_URL="redis://127.0.0.1:$REDIS_PORT"
    REDIS_RATE_LIMIT_URL="redis://127.0.0.1:$REDIS_PORT"
    NUQ_RABBITMQ_URL="amqp://guest:guest@127.0.0.1:$RMQ_PORT"

    export DATABASE_URL
    export NUQ_DATABASE_URL
    export REDIS_URL
    export REDIS_RATE_LIMIT_URL
    export NUQ_RABBITMQ_URL
    export PORT="$API_PORT"
    export HOST="127.0.0.1"
    export NODE_ENV=production
    export FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT=1
    export TEST_SUITE_SELF_HOSTED=true
    export ALLOW_LOCAL_WEBHOOKS=true
    export USE_DB_AUTHENTICATION=false
    export DISABLE_BLOCKLIST=true

    echo "[SMOKE] Starting Firecrawl harness on port $API_PORT..."
    firecrawl &
    FC_PID=$!
    CLEANUP_PIDS+=("$FC_PID")

    # Wait for liveness
    echo "[SMOKE] Waiting for Firecrawl liveness..."
    HEALTHY=false
    attempt=0
    while [ "$attempt" -lt 45 ]; do
      if curl -sf "http://127.0.0.1:$API_PORT/v0/health/liveness" >/dev/null 2>&1; then
        HEALTHY=true
        break
      fi
      sleep 2
      attempt=$((attempt + 1))
    done

    if [ "$HEALTHY" != "true" ]; then
      echo "[SMOKE] FAIL: Firecrawl did not become healthy within timeout."
      if kill -0 "$FC_PID" 2>/dev/null; then
        echo "[SMOKE] Firecrawl process still running (may be stuck initializing)."
      else
        echo "[SMOKE] Firecrawl process exited prematurely."
      fi
      exit 1
    fi
    echo "[SMOKE] Firecrawl is healthy."

    # Wait for readiness
    echo "[SMOKE] Waiting for Firecrawl readiness..."
    READY=false
    attempt=0
    while [ "$attempt" -lt 30 ]; do
      RESP=$(curl -sf "http://127.0.0.1:$API_PORT/v0/health/readiness" 2>/dev/null || echo "")
      if echo "$RESP" | jq -e '.status == "ok"' >/dev/null 2>&1; then
        READY=true
        break
      fi
      sleep 2
      attempt=$((attempt + 1))
    done

    if [ "$READY" != "true" ]; then
      echo "[SMOKE] FAIL: Firecrawl did not become ready within timeout."
      exit 1
    fi
    echo "[SMOKE] Firecrawl is ready."

    # -- Liveness check --
    echo "[SMOKE] Checking /v0/health/liveness..."
    LIVENESS=$(curl -sf "http://127.0.0.1:$API_PORT/v0/health/liveness")
    echo "[SMOKE] Liveness response: $LIVENESS"
    if [ "$(echo "$LIVENESS" | jq -r '.status')" != "ok" ]; then
      echo "[SMOKE] FAIL: Liveness endpoint did not return {\"status\":\"ok\"}"
      exit 1
    fi
    echo "[SMOKE] PASS: Liveness check OK."

    # -- Readiness check --
    echo "[SMOKE] Checking /v0/health/readiness..."
    READINESS=$(curl -sf "http://127.0.0.1:$API_PORT/v0/health/readiness")
    echo "[SMOKE] Readiness response: $READINESS"
    if [ "$(echo "$READINESS" | jq -r '.status')" != "ok" ]; then
      echo "[SMOKE] FAIL: Readiness endpoint did not return {\"status\":\"ok\"}"
      exit 1
    fi
    echo "[SMOKE] PASS: Readiness check OK."

    # -- Real scrape validation --
    echo "[SMOKE] Performing scrape against local HTTP fixture..."
    SCRAPE_RESP=$(curl -sf -X POST "http://127.0.0.1:$API_PORT/v1/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url":"http://127.0.0.1:'"$FIXTURE_PORT"'/","formats":["markdown"]}' 2>/dev/null || echo "")

    if [ -z "$SCRAPE_RESP" ]; then
      echo "[SMOKE] FAIL: /v1/scrape returned empty response (endpoint may require auth or be unavailable)."
      echo "[SMOKE] Try adding FIRE_ENGINE_API_KEY if upstream enforces auth."
      exit 1
    fi

    echo "[SMOKE] Scrape response: $(echo "$SCRAPE_RESP" | jq -c . 2>/dev/null || echo "$SCRAPE_RESP")"

    SCRAPE_SUCCESS=$(echo "$SCRAPE_RESP" | jq -r '.success // false')
    if [ "$SCRAPE_SUCCESS" != "true" ]; then
      echo "[SMOKE] FAIL: /v1/scrape did not return success=true."
      echo "[SMOKE] Response: $SCRAPE_RESP"
      exit 1
    fi

    SCRAPE_MD=$(echo "$SCRAPE_RESP" | jq -r '.data.markdown // ""')
    if ! echo "$SCRAPE_MD" | grep -q "Hello from Firecrawl smoke test"; then
      echo "[SMOKE] FAIL: Scraped markdown does not contain expected fixture text."
      echo "[SMOKE] Markdown: $SCRAPE_MD"
      exit 1
    fi

    echo "[SMOKE] PASS: Scrape returned expected markdown content."

    # -- v2 Scrape --
    echo "[SMOKE] Performing v2 scrape against local HTTP fixture..."
    V2_SCRAPE_RESP=$(curl -sf -X POST "http://127.0.0.1:$API_PORT/v2/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url":"http://127.0.0.1:'"$FIXTURE_PORT"'/"',"formats":["markdown"]}' 2>/dev/null || echo "")

    if [ -z "$V2_SCRAPE_RESP" ]; then
      echo "[SMOKE] FAIL: /v2/scrape returned empty response."
      exit 1
    fi

    echo "[SMOKE] v2 Scrape response: $(echo "$V2_SCRAPE_RESP" | jq -c . 2>/dev/null || echo "$V2_SCRAPE_RESP")"

    V2_SCRAPE_SUCCESS=$(echo "$V2_SCRAPE_RESP" | jq -r '.success // false')
    if [ "$V2_SCRAPE_SUCCESS" != "true" ]; then
      echo "[SMOKE] FAIL: /v2/scrape did not return success=true."
      echo "[SMOKE] Response: $V2_SCRAPE_RESP"
      exit 1
    fi

    V2_SCRAPE_MD=$(echo "$V2_SCRAPE_RESP" | jq -r '.data.markdown // ""')
    if ! echo "$V2_SCRAPE_MD" | grep -q "Hello from Firecrawl smoke test"; then
      echo "[SMOKE] FAIL: v2 scraped markdown does not contain expected fixture text."
      echo "[SMOKE] Markdown: $V2_SCRAPE_MD"
      exit 1
    fi

    echo "[SMOKE] PASS: v2 Scrape returned expected markdown content."

    # -- Auth bypass --
    echo "[SMOKE] Testing auth bypass (no auth header)..."
    BYPASS_NOAUTH_RESP=$(curl -sf -X POST "http://127.0.0.1:$API_PORT/v2/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url":"http://127.0.0.1:'"$FIXTURE_PORT"'/"',"formats":["markdown"]}' 2>/dev/null || echo "")

    if [ -z "$BYPASS_NOAUTH_RESP" ]; then
      echo "[SMOKE] FAIL: Auth bypass (no auth) returned empty response."
      exit 1
    fi

    BYPASS_NOAUTH_SUCCESS=$(echo "$BYPASS_NOAUTH_RESP" | jq -r '.success // false')
    if [ "$BYPASS_NOAUTH_SUCCESS" != "true" ]; then
      echo "[SMOKE] FAIL: Auth bypass (no auth) did not return success=true."
      echo "[SMOKE] Response: $BYPASS_NOAUTH_RESP"
      exit 1
    fi

    BYPASS_NOAUTH_MD=$(echo "$BYPASS_NOAUTH_RESP" | jq -r '.data.markdown // ""')
    if ! echo "$BYPASS_NOAUTH_MD" | grep -q "Hello from Firecrawl smoke test"; then
      echo "[SMOKE] FAIL: Auth bypass (no auth) markdown missing expected text."
      exit 1
    fi

    echo "[SMOKE] PASS: Auth bypass works without auth header."

    echo "[SMOKE] Testing auth bypass (bogus auth header)..."
    BYPASS_BOGAUTH_RESP=$(curl -sf -X POST "http://127.0.0.1:$API_PORT/v2/scrape" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer fake-key-12345" \
      -d '{"url":"http://127.0.0.1:'"$FIXTURE_PORT"'/"',"formats":["markdown"]}' 2>/dev/null || echo "")

    if [ -z "$BYPASS_BOGAUTH_RESP" ]; then
      echo "[SMOKE] FAIL: Auth bypass (bogus key) returned empty response."
      exit 1
    fi

    BYPASS_BOGAUTH_SUCCESS=$(echo "$BYPASS_BOGAUTH_RESP" | jq -r '.success // false')
    if [ "$BYPASS_BOGAUTH_SUCCESS" != "true" ]; then
      echo "[SMOKE] FAIL: Auth bypass (bogus key) did not return success=true."
      echo "[SMOKE] Response: $BYPASS_BOGAUTH_RESP"
      exit 1
    fi

    BYPASS_BOGAUTH_MD=$(echo "$BYPASS_BOGAUTH_RESP" | jq -r '.data.markdown // ""')
    if ! echo "$BYPASS_BOGAUTH_MD" | grep -q "Hello from Firecrawl smoke test"; then
      echo "[SMOKE] FAIL: Auth bypass (bogus key) markdown missing expected text."
      exit 1
    fi

    echo "[SMOKE] PASS: Auth bypass works with bogus auth header."

    # -- All passed --
    echo ""
    echo "[SMOKE] ========================================"
    echo "[SMOKE]  All Firecrawl smoke tests PASSED!"
    echo "[SMOKE]  - PostgreSQL:  localhost:$PG_PORT"
    echo "[SMOKE]  - Redis:       localhost:$REDIS_PORT"
    echo "[SMOKE]  - RabbitMQ:    localhost:$RMQ_PORT"
    echo "[SMOKE]  - API:         http://127.0.0.1:$API_PORT"
    echo "[SMOKE]  - Scrape:      http://127.0.0.1:$FIXTURE_PORT -> markdown OK"
    echo "[SMOKE]  - v2 Scrape:   http://127.0.0.1:$FIXTURE_PORT -> markdown OK"
    echo "[SMOKE]  - Auth bypass: works without/with bogus key"
    echo "[SMOKE] ========================================"
    echo ""
  '';
}
