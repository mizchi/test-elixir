import http from "k6/http";
import { check, group, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://127.0.0.1:4000";
const VUS = Number(__ENV.VUS || 10);
const DURATION = __ENV.DURATION || "15s";
const REMINDER_DUE_ON = __ENV.REMINDER_DUE_ON || "2026-03-15";

export const options = {
  scenarios: {
    app_http: {
      executor: "constant-vus",
      vus: VUS,
      duration: DURATION,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    checks: ["rate>0.99"],
    http_req_duration: ["p(95)<500"],
  },
};

export default function () {
  group("landing page", function () {
    const response = http.get(`${BASE_URL}/`, {
      tags: { name: "GET /" },
    });

    check(response, {
      "GET / returns 200": (res) => res.status === 200,
      "GET / includes API index": (res) => res.body.includes("TestElixir API"),
    });
  });

  group("connect four lobby", function () {
    const response = http.get(`${BASE_URL}/connect-four`, {
      tags: { name: "GET /connect-four" },
    });

    check(response, {
      "GET /connect-four returns 200": (res) => res.status === 200,
      "GET /connect-four includes Create Room": (res) => res.body.includes("Create Room"),
    });
  });

  group("reminders index", function () {
    const response = http.get(`${BASE_URL}/api/reminders`, {
      tags: { name: "GET /api/reminders" },
    });

    check(response, {
      "GET /api/reminders returns 200": (res) => res.status === 200,
      "GET /api/reminders returns JSON data": (res) => Array.isArray(res.json("data")),
    });
  });

  group("create reminder", function () {
    const title = `bench-${__VU}-${__ITER}`;
    const payload = JSON.stringify({
      title,
      due_on: REMINDER_DUE_ON,
    });

    const response = http.post(`${BASE_URL}/api/reminders`, payload, {
      headers: { "content-type": "application/json" },
      tags: { name: "POST /api/reminders" },
    });

    check(response, {
      "POST /api/reminders returns 201": (res) => res.status === 201,
      "POST /api/reminders echoes title": (res) => res.json("data.title") === title,
    });
  });

  group("create connect four room", function () {
    const response = http.post(`${BASE_URL}/api/connect-four/rooms`, null, {
      tags: { name: "POST /api/connect-four/rooms" },
    });

    check(response, {
      "POST /api/connect-four/rooms returns 201": (res) => res.status === 201,
      "POST /api/connect-four/rooms returns room_id": (res) =>
        typeof res.json("data.room_id") === "string" && res.json("data.room_id").length > 0,
    });
  });

  sleep(1);
}
