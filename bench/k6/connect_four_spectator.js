import http from "k6/http";
import { check } from "k6";
import { Counter, Trend } from "k6/metrics";
import { WebSocket } from "k6/experimental/websockets";

const BASE_URL = __ENV.BASE_URL || "http://127.0.0.1:4000";
const WS_BASE_URL = (__ENV.WS_BASE_URL || BASE_URL).replace(/^http/, "ws");
const VUS = Number(__ENV.VUS || 5);
const DURATION = __ENV.DURATION || "15s";
const GAME_TIMEOUT_MS = Number(__ENV.GAME_TIMEOUT_MS || 2500);

const MOVE_SEQUENCE = [
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
];

const spectatorJoinDuration = new Trend("spectator_join_duration", true);
const spectatorUpdateDeliveryDuration = new Trend("spectator_update_delivery_duration", true);
const spectatorMatchDuration = new Trend("spectator_match_duration", true);
const roomsCreatedTotal = new Counter("rooms_created_total");
const spectatorMatchesCompletedTotal = new Counter("spectator_matches_completed_total");
const spectatorStateUpdatesTotal = new Counter("spectator_state_updates_total");
const spectatorRejectionsTotal = new Counter("spectator_rejections_total");
const matchMovesSentTotal = new Counter("match_moves_sent_total");

export const options = {
  scenarios: {
    connect_four_spectator: {
      executor: "constant-vus",
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
    spectator_join_duration: ["p(95)<300"],
    spectator_update_delivery_duration: ["p(95)<200"],
    spectator_match_duration: ["p(95)<1800"],
  },
};

export default function () {
  const createRoomResponse = http.post(`${BASE_URL}/api/connect-four/rooms`, null, {
    tags: { name: "POST /api/connect-four/rooms" },
  });

  const roomCreated = check(createRoomResponse, {
    "spectator room create returns 201": (res) => res.status === 201,
  });

  if (!roomCreated) {
    return;
  }

  roomsCreatedTotal.add(1);

  const roomId = createRoomResponse.json("data.room_id");
  const topic = `connect_four:${roomId}`;
  const startedAt = Date.now();

  const state = {
    closed: false,
    complete: false,
    finalized: false,
    spectatorStarted: false,
    moveIndex: 0,
    moveInFlight: false,
    spectatorProbeInFlight: false,
    spectatorRejectSeen: false,
    spectatorUpdateCount: 0,
    spectatorStatus: null,
    spectatorWinner: null,
    pendingSpectatorUpdateAt: null,
    winner: null,
    status: null,
    error: null,
    startedAt,
    players: {
      alice: null,
      bob: null,
      carol: null,
    },
  };

  state.players.alice = connectClient("alice", roomId, topic, state);
  state.players.bob = connectClient("bob", roomId, topic, state);

  const intervalId = setInterval(function () {
    if (state.finalized) {
      return;
    }

    if (!state.spectatorStarted && playersJoined(state) && !samePlayerColor(state)) {
      state.spectatorStarted = true;
      state.players.carol = connectClient("carol", roomId, topic, state);
    }

    if (!state.complete && state.error === null && Date.now() >= startedAt + GAME_TIMEOUT_MS) {
      state.error = "spectator_match_timeout";
    }

    if (state.complete || state.error !== null) {
      finalizeScenario(state, intervalId);
    }
  }, 25);
}

function connectClient(label, roomId, topic, state) {
  const playerId = `${label}-${__VU}-${__ITER}`;
  const url = `${WS_BASE_URL}/socket/websocket?vsn=2.0.0&player_id=${encodeURIComponent(playerId)}`;
  const socket = new WebSocket(url);

  const client = {
    label,
    playerId,
    socket,
    topic,
    joined: false,
    joinRef: null,
    role: null,
    color: null,
    nextRef: 1,
    pending: {},
  };

  socket.addEventListener("open", function () {
    sendJoin(client);
  });

  socket.addEventListener("message", function (event) {
    const message = JSON.parse(event.data);
    handleMessage(client, message, roomId, state);
  });

  socket.addEventListener("error", function () {
    state.error = state.error || `${label}_socket_error`;
  });

  socket.addEventListener("close", function () {
    if (!state.closed && !state.complete && state.error === null) {
      state.error = `${label}_socket_closed_early`;
    }
  });

  return client;
}

function handleMessage(client, message, roomId, state) {
  const event = message[3];
  const payload = message[4];

  if (event === "phx_reply") {
    handleReply(client, message[1], payload, roomId, state);
    return;
  }

  if (event === "state_updated") {
    handleStateUpdated(client, payload.state, state);
  }
}

function handleReply(client, ref, payload, roomId, state) {
  const pending = client.pending[ref];

  if (!pending) {
    return;
  }

  delete client.pending[ref];

  if (pending.type === "spectator_probe") {
    state.spectatorProbeInFlight = false;

    if (payload.status === "error" && payload.response && payload.response.detail === "spectator_cannot_play") {
      state.spectatorRejectSeen = true;
      spectatorRejectionsTotal.add(1);
      maybeAdvanceScenario(state);
      return;
    }

    state.error = "spectator_probe_unexpected_reply";
    return;
  }

  if (payload.status !== "ok") {
    const detail =
      payload.response && payload.response.detail ? payload.response.detail : "failed";

    state.error = `${client.label}_${pending.type}_${detail}`;
    return;
  }

  if (pending.type === "join") {
    client.joined = true;
    client.role = payload.response.player_role;
    client.color = payload.response.player_color;

    if (payload.response.state.room_id !== roomId) {
      state.error = `${client.label}_unexpected_room`;
      return;
    }

    if (client.label === "carol") {
      spectatorJoinDuration.add(Date.now() - pending.startedAt);

      if (client.role !== "spectator" || client.color !== null) {
        state.error = "spectator_unexpected_role";
        return;
      }

      if (!payload.response.state.spectators.includes(client.playerId)) {
        state.error = "spectator_missing_from_state";
        return;
      }
    } else {
      if (client.color !== "red" && client.color !== "yellow") {
        state.error = `${client.label}_unexpected_color`;
        return;
      }

      if (client.role !== client.color) {
        state.error = `${client.label}_unexpected_role`;
        return;
      }
    }

    if (playersJoined(state) && samePlayerColor(state)) {
      state.error = "duplicate_player_colors";
      return;
    }

    maybeAdvanceScenario(state);
    return;
  }

  if (pending.type === "move") {
    state.moveInFlight = false;
    state.moveIndex += 1;
    maybeAdvanceScenario(state);
  }
}

function handleStateUpdated(client, nextState, state) {
  state.status = nextState.status;
  state.winner = nextState.winner;

  if (client.label === "carol") {
    state.spectatorUpdateCount += 1;
    spectatorStateUpdatesTotal.add(1);
    state.spectatorStatus = nextState.status;
    state.spectatorWinner = nextState.winner;

    if (state.pendingSpectatorUpdateAt !== null) {
      spectatorUpdateDeliveryDuration.add(Date.now() - state.pendingSpectatorUpdateAt);
      state.pendingSpectatorUpdateAt = null;
    }

    if (!state.complete && nextState.status === "won" && nextState.winner === "red") {
      state.complete = true;
      spectatorMatchDuration.add(Date.now() - state.startedAt);
      spectatorMatchesCompletedTotal.add(1);
    }
  }
}

function maybeAdvanceScenario(state) {
  if (state.error !== null || state.complete || state.moveInFlight || state.spectatorProbeInFlight) {
    return;
  }

  if (!allJoined(state)) {
    return;
  }

  if (!state.spectatorRejectSeen) {
    state.spectatorProbeInFlight = true;
    sendSpectatorProbe(state.players.carol);
    return;
  }

  const nextMove = MOVE_SEQUENCE[state.moveIndex];

  if (!nextMove) {
    return;
  }

  const player = playerForColor(state, nextMove.color);

  if (!player) {
    state.error = `missing_${nextMove.color}_player`;
    return;
  }

  state.moveInFlight = true;
  state.pendingSpectatorUpdateAt = Date.now();
  sendMove(player, nextMove.column);
}

function sendJoin(client) {
  const ref = nextRef(client);
  client.joinRef = ref;
  client.pending[ref] = { type: "join", startedAt: Date.now() };
  client.socket.send(JSON.stringify([ref, ref, client.topic, "phx_join", {}]));
}

function sendMove(client, column) {
  const ref = nextRef(client);
  client.pending[ref] = { type: "move", startedAt: Date.now() };
  matchMovesSentTotal.add(1);
  client.socket.send(JSON.stringify([client.joinRef, ref, client.topic, "drop_token", { column }]));
}

function sendSpectatorProbe(client) {
  const ref = nextRef(client);
  client.pending[ref] = { type: "spectator_probe", startedAt: Date.now() };
  client.socket.send(JSON.stringify([client.joinRef, ref, client.topic, "drop_token", { column: 0 }]));
}

function nextRef(client) {
  const ref = String(client.nextRef);
  client.nextRef += 1;
  return ref;
}

function allJoined(state) {
  return (
    state.players.alice &&
    state.players.alice.joined &&
    state.players.bob &&
    state.players.bob.joined &&
    state.players.carol &&
    state.players.carol.joined
  );
}

function playersJoined(state) {
  return state.players.alice && state.players.alice.joined && state.players.bob && state.players.bob.joined;
}

function samePlayerColor(state) {
  return (
    state.players.alice &&
    state.players.bob &&
    state.players.alice.color !== null &&
    state.players.alice.color === state.players.bob.color
  );
}

function playerForColor(state, color) {
  return Object.values(state.players).find((player) => player.color === color);
}

function closeClients(state) {
  state.closed = true;

  Object.values(state.players).forEach((client) => {
    if (client && client.socket && client.socket.readyState < 2) {
      client.socket.close();
    }
  });
}

function finalizeScenario(state, intervalId) {
  state.finalized = true;
  clearInterval(intervalId);
  closeClients(state);

  if (
    state.error !== null ||
    state.spectatorRejectSeen !== true ||
    state.spectatorStatus !== "won" ||
    state.spectatorWinner !== "red"
  ) {
    console.error(
      JSON.stringify({
        error: state.error,
        spectatorRejectSeen: state.spectatorRejectSeen,
        spectatorStatus: state.spectatorStatus,
        spectatorWinner: state.spectatorWinner,
        spectatorUpdateCount: state.spectatorUpdateCount,
        moveIndex: state.moveIndex,
      }),
    );
  }

  check(state, {
    "spectator scenario has no protocol error": (current) => current.error === null,
    "all three clients joined": (current) =>
      current.players.alice.joined && current.players.bob.joined && current.players.carol.joined,
    "spectator move is rejected": (current) => current.spectatorRejectSeen === true,
    "spectator receives match updates": (current) => current.spectatorUpdateCount >= MOVE_SEQUENCE.length,
    "spectator sees red win": (current) =>
      current.spectatorStatus === "won" && current.spectatorWinner === "red",
  });
}
