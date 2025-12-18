import { WebSocketServer } from "ws";
import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL || "redis://redis:6379");

const wss = new WebSocketServer({ port: 3001 });

wss.on("connection", (ws) => {
  ws.send(JSON.stringify({ type: "welcome", ok: true }));

  ws.on("message", (msg) => {
    redis.publish("realtime", msg.toString());
  });
});

console.log("WebSocket server listening on 3001");