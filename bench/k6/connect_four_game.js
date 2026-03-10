import http from "k6/http";
import { check } from "k6";
import { Trend } from "k6/metrics";
import { WebSocket } from "k6/experimental/websockets";

const BASE_URL = __ENV.BASE_URL || "http://127.0.0.1:4000";
const WS_BASE_URL = (__ENV.WS_BASE_URL || BASE_URL).replace(/^http/, "ws");
const VUS = Number(__ENV.VUS || 5);
const DURATION = __ENV.DURATION || "15s";
const GAME_TIMEOUT_MS = Number(__ENV.GAME_TIMEOUT_MS || 2000);

const MOVE_SEQUENCE = [
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
  { color: "yellow", column: 1 },
  { color: "red", column: 0 },
];

const joinDuration = new Trend("match_join_duration", true);
const moveReplyDuration = new Trend("match_move_reply_duration", true);
const matchDuration = new Trend("match_duration", true);

export const options = {
  scenarios: {
    connect_four_match: {
      executor: "constant-vus",
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
    match_join_duration: ["p(95)<300"],
    match_move_reply_duration: ["p(95)<200"],
    match_duration: ["p(95)<1500"],
  },
};

export default function () {
  const createRoomResponse = http.post(`${BASE_URL}/api/connect-four/rooms`, null, {
    tags: { name: "POST /api/connect-four/rooms" },
  });

  const roomCreated = check(createRoomResponse, {
    "match room create returns 201": (res) => res.status === 201,
  });

  if (!roomCreated) {
    return;
  }

  const roomId = createRoomResponse.json("data.room_id");
  const topic = `connect_four:${roomId}`;
  const startedAt = Date.now();

  const state = {
    closed: false,
    complete: false,
    finalized: false,
    moveIndex: 0,
    moveInFlight: false,
    winner: null,
    status: null,
    error: null,
    startedAt,
    players: {},
  };

  state.players.alice = connectPlayer("alice", roomId, topic, state);
  state.players.bob = connectPlayer("bob", roomId, topic, state);

  const intervalId = setInterval(function () {
    if (state.finalized) {
      return;
    }

    if (!state.complete && state.error === null && Date.now() >= startedAt + GAME_TIMEOUT_MS) {
      state.error = "match_timeout";
    }

    if (state.complete || state.error !== null) {
      finalizeMatch(state, intervalId);
    }
  }, 25);
}

function connectPlayer(label, roomId, topic, state) {
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
    const nextState = payload.state;
    state.status = nextState.status;
    state.winner = nextState.winner;

    if (nextState.status === "won" && nextState.winner === "red") {
      state.complete = true;
      matchDuration.add(Date.now() - state.startedAt);
    }
  }
}

function handleReply(client, ref, payload, roomId, state) {
  const pending = client.pending[ref];

  if (!pending) {
    return;
  }

  delete client.pending[ref];

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
    client.startedAt = pending.startedAt;
    joinDuration.add(Date.now() - pending.startedAt);

    if (payload.response.state.room_id !== roomId) {
      state.error = `${client.label}_unexpected_room`;
      return;
    }

    if (client.color !== "red" && client.color !== "yellow") {
      state.error = `${client.label}_unexpected_color`;
      return;
    }

    if (state.players.alice.joined && state.players.bob.joined) {
      if (state.players.alice.color === state.players.bob.color) {
        state.error = "duplicate_player_colors";
        return;
      }
    }

    if (client.role !== client.color) {
      state.error = `${client.label}_unexpected_role`;
      return;
    }

    maybeSendNextMove(state);
    return;
  }

  if (pending.type === "move") {
    moveReplyDuration.add(Date.now() - pending.startedAt);
    state.moveInFlight = false;
    state.moveIndex += 1;
    maybeSendNextMove(state);
  }
}

function maybeSendNextMove(state) {
  if (state.error !== null || state.complete || state.moveInFlight) {
    return;
  }

  if (!state.players.alice.joined || !state.players.bob.joined) {
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
  client.pending[ref] = { type: "move", column, startedAt: Date.now() };
  client.socket.send(JSON.stringify([client.joinRef, ref, client.topic, "drop_token", { column }]));
}

function nextRef(client) {
  const ref = String(client.nextRef);
  client.nextRef += 1;
  return ref;
}

function closePlayers(state) {
  state.closed = true;

  Object.values(state.players).forEach((client) => {
    if (client && client.socket && client.socket.readyState < 2) {
      client.socket.close();
    }
  });
}

function playerForColor(state, color) {
  return Object.values(state.players).find((player) => player.color === color);
}

function finalizeMatch(state, intervalId) {
  state.finalized = true;
  clearInterval(intervalId);
  closePlayers(state);

  if (state.error !== null || state.status !== "won" || state.winner !== "red") {
    console.error(
      JSON.stringify({
        error: state.error,
        status: state.status,
        winner: state.winner,
        moveIndex: state.moveIndex,
      }),
    );
  }

  check(state, {
    "match has no protocol error": (current) => current.error === null,
    "both players joined": (current) =>
      current.players.alice.joined === true && current.players.bob.joined === true,
    "match reaches a red win": (current) =>
      current.status === "won" && current.winner === "red",
  });
}
