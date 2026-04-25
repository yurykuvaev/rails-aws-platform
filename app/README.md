# Pokemon Battle API

[![App CI/CD](https://github.com/yurykuvaev/rails-aws-platform/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/yurykuvaev/rails-aws-platform/actions/workflows/deploy.yml)

A minimal Rails 7 JSON API: turn-based Pokemon-style battles with persistent characters, XP, and leveling. Built as a learning sandbox for deployment pipelines and debug scenarios — there are deliberate quirks (race conditions, N+1 queries, imperfect cooldowns, small connection pool) to practice on.

**Stack:** Rails 7.1 · Ruby 3.2 · MySQL 8 · Puma · RSpec · Docker.

**Live (dev):** http://rails-app-dev-alb-92563372.us-east-1.elb.amazonaws.com — try `GET /health`.

## Quick start

Only Docker Desktop is required — no local Ruby or MySQL.

### 1. Generate `Gemfile.lock` (one time)

The Dockerfile uses `BUNDLE_DEPLOYMENT=1`, which requires a lockfile. If you have Ruby locally:

```bash
bundle lock --add-platform x86_64-linux
```

If you don't (e.g. fresh Windows machine), use Docker to generate it:

```powershell
docker run --rm -v "${PWD}:/app" -w /app ruby:3.2 bundle lock --add-platform x86_64-linux
```

The `--add-platform x86_64-linux` flag is critical so bundler also resolves Linux-native gems (like `mysql2`) for the container.

### 2. Bring up the stack

```powershell
docker compose up -d --build
```

`-d` runs in detached mode so your terminal stays free. Tail logs with:

```powershell
docker compose logs -f web
```

### 3. Seed the database and verify

```powershell
docker compose exec web bundle exec rails db:seed
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/leaderboard
```

> **Windows note**: in PowerShell, `curl` is an alias for `Invoke-WebRequest`. Use `curl.exe` (real cURL ships with Windows 10+) or switch to `Invoke-RestMethod` for cleaner JSON handling.

## Day-to-day commands

| Command | What it does |
|---|---|
| `docker compose up -d` | Start stack in background |
| `docker compose ps` | See what's running |
| `docker compose logs -f web` | Follow web logs (Ctrl+C only stops the stream) |
| `docker compose exec web bash` | Shell into the web container |
| `docker compose exec web bundle exec rspec` | Run tests |
| `docker compose restart web` | Restart after a `Gemfile` change (no rebuild needed for code changes — Rails auto-reloads in dev) |
| `docker compose down` | Stop everything (data persists) |
| `docker compose down -v` | Stop and **delete the MySQL volume** (fresh DB next start) |

## Running tests

```powershell
docker compose exec web bundle exec rspec
```

If RSpec complains the test DB doesn't exist:

```powershell
docker compose exec -e RAILS_ENV=test web bundle exec rails db:create db:migrate
```

## Domain

| Model        | Purpose |
|--------------|---------|
| `Player`     | Username + auto-generated 32-char API token |
| `Character`  | Belongs to player. Stats: HP, attack, defense, speed, element, level, XP. Max 5 per player. |
| `Battle`     | Two characters fighting. Status: pending → in_progress → completed. |
| `BattleTurn` | Per-turn record: damage, crit flag, defender HP afterward. |

## Endpoints

Auth: send `X-Api-Token: <token>` on protected routes.

### Public

| Method | Path                  | Description |
|--------|-----------------------|-------------|
| GET    | `/health`             | DB ping + uptime |
| GET    | `/leaderboard`        | Top 20 characters by wins (deliberate N+1) |
| GET    | `/characters/:id`     | Character stats + recent battles |
| GET    | `/battles/:id`        | Battle with all turns |

### Authenticated

| Method | Path                          | Description |
|--------|-------------------------------|-------------|
| POST   | `/players`                    | Create player → returns `api_token` |
| GET    | `/players/me`                 | Current player + their characters |
| POST   | `/characters`                 | Create character (max 5 per player) |
| POST   | `/characters/:id/heal`        | Restore HP. 60s cooldown via `updated_at`. |
| POST   | `/battles`                    | Create pending battle |
| POST   | `/battles/:id/attack`         | Execute one turn. **Not idempotent** — POST twice and both turns happen. |

## Walkthrough

### Bash / Linux / macOS

```bash
# 1. Create a player and grab the token
TOKEN=$(curl -s -X POST localhost:3000/players \
  -H 'Content-Type: application/json' \
  -d '{"username":"ash"}' | jq -r .api_token)

# 2. Create a character
ATTACKER_ID=$(curl -s -X POST localhost:3000/characters \
  -H "X-Api-Token: $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"Pikachu","element":"electric"}' | jq -r .id)

# 3. Create another player + character to fight against
TOKEN2=$(curl -s -X POST localhost:3000/players \
  -H 'Content-Type: application/json' \
  -d '{"username":"misty"}' | jq -r .api_token)

DEFENDER_ID=$(curl -s -X POST localhost:3000/characters \
  -H "X-Api-Token: $TOKEN2" -H 'Content-Type: application/json' \
  -d '{"name":"Staryu","element":"water"}' | jq -r .id)

# 4. Start a battle
BATTLE_ID=$(curl -s -X POST localhost:3000/battles \
  -H "X-Api-Token: $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"attacker_character_id\":$ATTACKER_ID,\"defender_character_id\":$DEFENDER_ID}" \
  | jq -r .id)

# 5. Attack until the defender is down
while true; do
  RESULT=$(curl -s -X POST "localhost:3000/battles/$BATTLE_ID/attack" \
    -H "X-Api-Token: $TOKEN")
  echo "$RESULT" | jq '{turn: .turn, hp: .defender_hp, status: .battle_status}'
  [ "$(echo $RESULT | jq -r .battle_status)" = "completed" ] && break
done

# 6. Heal Pikachu (waits at least 60s after last update)
curl -s -X POST "localhost:3000/characters/$ATTACKER_ID/heal" \
  -H "X-Api-Token: $TOKEN" | jq

# 7. Leaderboard
curl -s localhost:3000/leaderboard | jq
```

### PowerShell (Windows)

`Invoke-RestMethod` parses JSON automatically — no need for `jq`:

```powershell
# 1. Create a player and grab the token
$body = @{ username = 'ash' } | ConvertTo-Json
$TOKEN = (Invoke-RestMethod -Method Post -Uri http://localhost:3000/players `
  -ContentType 'application/json' -Body $body).api_token

# 2. Create a character
$body = @{ name = 'Pikachu'; element = 'electric' } | ConvertTo-Json
$ATTACKER = Invoke-RestMethod -Method Post -Uri http://localhost:3000/characters `
  -Headers @{ 'X-Api-Token' = $TOKEN } -ContentType 'application/json' -Body $body

# 3. Second player + defender
$body = @{ username = 'misty' } | ConvertTo-Json
$TOKEN2 = (Invoke-RestMethod -Method Post -Uri http://localhost:3000/players `
  -ContentType 'application/json' -Body $body).api_token

$body = @{ name = 'Staryu'; element = 'water' } | ConvertTo-Json
$DEFENDER = Invoke-RestMethod -Method Post -Uri http://localhost:3000/characters `
  -Headers @{ 'X-Api-Token' = $TOKEN2 } -ContentType 'application/json' -Body $body

# 4. Start a battle
$body = @{ attacker_character_id = $ATTACKER.id; defender_character_id = $DEFENDER.id } | ConvertTo-Json
$BATTLE = Invoke-RestMethod -Method Post -Uri http://localhost:3000/battles `
  -Headers @{ 'X-Api-Token' = $TOKEN } -ContentType 'application/json' -Body $body

# 5. Attack until the defender is down
do {
  $r = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/battles/$($BATTLE.id)/attack" `
    -Headers @{ 'X-Api-Token' = $TOKEN }
  Write-Host "turn $($r.turn.turn_number) | hp $($r.defender_hp) | status $($r.battle_status)"
} while ($r.battle_status -ne 'completed')

# 6. Leaderboard
Invoke-RestMethod http://localhost:3000/leaderboard | Format-Table
```

## Element advantages

| Attacker | Strong vs |
|----------|-----------|
| fire     | grass     |
| grass    | water     |
| water    | fire      |
| electric | water     |

Same element → 0.5× damage. No relation → 1.0×.

Damage formula: `max(1, (attack * 1.5 - defense) * element_multiplier * crit_multiplier)`. Crit chance 10% for 2× damage.

## Deliberate quirks (for debug practice)

- **Race condition** in `BattleEngine#execute_turn` — no transaction, no row lock. Two concurrent `POST /battles/:id/attack` requests both read stale HP and apply damage independently.
- **N+1 query** in `LeaderboardController#index` — each row triggers a separate SELECT for `player.username`.
- **Imperfect heal cooldown** — uses `updated_at`, so any field update (e.g. taking damage) resets it. Try to heal mid-battle and observe the bug.
- **Small connection pool** (`pool: 5`) — easy to exhaust under concurrent attacks. Watch for `ActiveRecord::ConnectionTimeoutError`.
- **No idempotency** on `/battles/:id/attack` — sending the same request twice triggers two turns.

## Build modes

The same `Dockerfile` serves both local dev and production CI, controlled by the `BUNDLE_WITHOUT` build arg:

| Context | `BUNDLE_WITHOUT` value | Result |
|---|---|---|
| `docker compose up --build` (this repo's `docker-compose.yml`) | `""` (empty) | Installs every gem — faker, rspec, factory_bot included |
| `docker build .` in CI/CD | `"development:test"` (Dockerfile default) | Lean image, no test/dev gems |

If you need to test the production-style image locally:

```powershell
docker build -t app-prod .
```

## Architecture

This `app/` directory is a Rails project root. Inside the project Rails uses a nested `app/` for its standard tree (`app/models`, `app/controllers`, `app/services`). The outer `app/` exists because the deployment monorepo separates `infra/` (Terraform) from `app/` (the Rails application).
