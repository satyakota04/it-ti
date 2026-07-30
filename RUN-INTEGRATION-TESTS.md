# Running Integration Tests with Call Graph (CG) Validation

## Quick Start

```bash
cd /Users/satya/Git/it-ti

# Build agents first (one time)
./build-native-agent.sh
./build-ti-agent.sh

# Terminal 1–3: start services with TI agent
./run-shipping.sh
./run-inventory.sh
./run-order.sh

# Terminal 4: run the slim Select*IT suite (agent on test JVM)
./run-it-ti.sh

# Terminal 5: check classification
./check-all-classification.sh
```

Or without TI on the test runner (services already up):

```bash
mvn test
```

## What the Scripts Do

### Service Scripts
- **`run-order.sh`** - Starts order-service on port 8081 with TI agent
- **`run-inventory.sh`** - Starts inventory-service on port 8082 with TI agent
- **`run-shipping.sh`** - Starts shipping-service on port 8083 with TI agent

All services:
- Log classification to `/tmp/ti-it/<service>/native-agent.log`
- Write call graphs to `/tmp/ti-it/<service>/native/cg_*.json`

### Service URLs

Single config: [`services.properties`](services.properties)

```
order.service.url=http://localhost:8081
inventory.service.url=http://localhost:8082
shipping.service.url=http://localhost:8083
```

Tests and runner scripts read URLs from this file (system properties / env still override).

### Test Scripts
- **`run-it-ti.sh`** - Runs `mvn -f pom.xml test` with TI agent on the forked test JVM
- **`run-it.sh`** - Builds sibling service JARs, starts them, runs tests, stops them

### Check Scripts
- **`check-all-classification.sh`** - Check all three services

## Slim test suite (one IT per file, disjoint file ownership)

A = order, B = inventory, C = shipping. Shared helpers in `ItSupport`.

1. **`SelectAbcIT`** — A→B→C: `POST /orders` + `GET /orders/{id}`
2. **`SelectBacIT`** — B→A→C: `GET /stock-order/{sku}`
3. **`SelectCabIT`** — C→A→B: `GET /ship-order/{sku}`

See [`TEST-CLASS-COVERAGE.md`](TEST-CLASS-COVERAGE.md) for the disjoint file matrix.

## Ports / URLs

Configured in `services.properties` (defaults: order 8081, inventory 8082, shipping 8083).

## Call Graph Output

After running tests with agents attached:

- `/tmp/ti-it/order/native/cg_*.json`
- `/tmp/ti-it/inventory/native/cg_*.json`
- `/tmp/ti-it/shipping/native/cg_*.json`

These should ONLY contain user classes (`com.harness.sample.*`), not dependency classes.

## Troubleshooting

### Services won't start
```bash
lsof -ti:8081,8082,8083
pkill -f "order-service-1.0-SNAPSHOT.jar"
pkill -f "inventory-service-1.0-SNAPSHOT.jar"
pkill -f "shipping-service-1.0-SNAPSHOT.jar"
```

### No classification logs
```bash
ls -la /Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar
ls -la /Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib
grep "Attaching Harness TI Agent" /tmp/ti-it/*/console.log
```
