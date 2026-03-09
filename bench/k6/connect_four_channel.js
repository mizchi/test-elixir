import http from "k6/http";
import ws from "k6/ws";
import { check } from "k6";
import { Trend } from "k6/metrics";

const BASE_URL = __ENV.BASE_URL || "http://127.0.0.1:4000";
const WS_BASE_URL = (__ENV.WS_BASE_URL || BASE_URL).replace(/^http/, "ws");
const VUS = Number(__ENV.VUS || 10);
const DURATION = __ENV.DURATION || "15s";
const JOIN_TIMEOUT_MS = Number(__ENV.JOIN_TIMEOUT_MS || 1000);

const channelJoinDuration = new Trend("channel_join_duration", true);

export const options = {
  scenarios: {
    channel_join: {
      executor: "constant-vus",
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
    channel_join_duration: ["p(95)<300"],
  },
};

export default function () {
  const createRoomResponse = http.post(`${BASE_URL}/api/connect-four/rooms`, null, {
    tags: { name: "POST /api/connect-four/rooms" },
  });

  const roomCreated = check(createRoomResponse, {
    "room create returns 201": (res) => res.status === 201,
  });

  if (!roomCreated) {
    return;
  }

  const roomId = createRoomResponse.json("data.room_id");
  const topic = `connect_four:${roomId}`;
  const playerId = `bench-${__VU}-${__ITER}`;
  const url = `${WS_BASE_URL}/socket/websocket?vsn=2.0.0&player_id=${encodeURIComponent(playerId)}`;

  let joinSucceeded = false;
  let joinStartedAt = 0;
  let responseError = null;

  const response = ws.connect(url, {}, function (socket) {
    socket.on("open", function () {
      joinStartedAt = Date.now();
      socket.send(JSON.stringify(["1", "1", topic, "phx_join", {}]));
    });

    socket.on("message", function (rawMessage) {
      const message = JSON.parse(rawMessage);
      const event = message[3];
      const payload = message[4];

      if (event === "phx_reply" && payload.status === "ok") {
        joinSucceeded = payload.response.state.room_id === roomId;

        if (joinSucceeded) {
          channelJoinDuration.add(Date.now() - joinStartedAt);
        } else {
          responseError = "unexpected_room_id";
        }

        socket.close();
      }
    });

    socket.setTimeout(function () {
      responseError = responseError || "join_timeout";
      socket.close();
    }, JOIN_TIMEOUT_MS);
  });

  check(response, {
    "websocket handshake returns 101": (res) => res && res.status === 101,
    "channel join succeeds": () => joinSucceeded,
    "channel join has no protocol error": () => responseError === null,
  });
}
