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

ci: quality typecheck
