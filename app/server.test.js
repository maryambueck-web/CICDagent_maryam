const test = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const { handler } = require("./server");

function get(path) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(handler).listen(0, () => {
      http
        .get({ port: server.address().port, path }, (res) => {
          let body = "";
          res.on("data", (c) => (body += c));
          res.on("end", () => server.close(() => resolve({ status: res.statusCode, body })));
        })
        .on("error", reject);
    });
  });
}

test("health endpoint returns ok", async () => {
  const r = await get("/healthz");
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.body, "ok");
});

test("root returns app metadata", async () => {
  const r = await get("/");
  assert.strictEqual(r.status, 200);
  assert.strictEqual(JSON.parse(r.body).app, "cicdagent-sample");
});
