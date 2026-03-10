set shell := ["bash", "-cu"]

default:
  @just --list

setup:
  mix setup

server:
  mix phx.server

test:
  mix test

cover:
  mix test --cover

quality:
  mix quality

typecheck:
  mix typecheck

bench-http *args:
  k6 run bench/k6/http_api.js {{args}}

bench-channel *args:
  k6 run bench/k6/connect_four_channel.js {{args}}

bench-game *args:
  k6 run bench/k6/connect_four_game.js {{args}}

bench-spectator *args:
  k6 run bench/k6/connect_four_spectator.js {{args}}

bench-soak *args:
  VUS="${VUS:-20}" DURATION="${DURATION:-5m}" GAME_TIMEOUT_MS="${GAME_TIMEOUT_MS:-5000}" k6 run bench/k6/connect_four_spectator.js {{args}}

ci: quality typecheck
