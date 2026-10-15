const test = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { execFile, spawnSync } = require("node:child_process");
const { handler } = require("./server");

function get(path, env = {}) {
  const saved = {};
  for (const k of Object.keys(env)) {
    saved[k] = process.env[k];
    process.env[k] = env[k];
  }
  const restore = () => {
    for (const k of Object.keys(saved)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  };
  return getRaw(path).finally(restore);
}

function getRaw(path) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(handler).listen(0, () => {
      http
        .get({ port: server.address().port, path }, (res) => {
          let body = "";
          res.on("data", (c) => (body += c));
          res.on("end", () =>
            server.close(() => resolve({ status: res.statusCode, headers: res.headers, body })),
          );
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

test("ready endpoint returns exactly {\"status\":\"ok\"} as JSON with 200", async () => {
  const r = await get("/ready");
  assert.strictEqual(r.status, 200);
  assert.match(r.headers["content-type"], /^application\/json/);
  assert.strictEqual(r.body, '{"status":"ok"}');
});

test("root returns app metadata", async () => {
  const r = await get("/");
  assert.strictEqual(r.status, 200);
  assert.strictEqual(JSON.parse(r.body).app, "cicdagent-sample");
});

test("ready ignores query strings", async () => {
  const r = await get("/ready?probe=1");
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.body, '{"status":"ok"}');
});

test("root reports APP_VERSION and defaults to dev", async () => {
  assert.strictEqual(JSON.parse((await get("/", { APP_VERSION: "abc123" })).body).version, "abc123");
  assert.strictEqual(JSON.parse((await get("/", { APP_VERSION: "" })).body).version, "dev");
});

test("Dockerfile runs as a non-root user and pins a major base image tag", () => {
  const d = fs.readFileSync(path.join(__dirname, "Dockerfile"), "utf8");
  assert.match(d, /^FROM node:\d+/m);
  assert.doesNotMatch(d, /:latest/);
  assert.match(d, /^USER node$/m);
});

test("package.json declares no unexpected runtime dependencies", () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "package.json"), "utf8"));
  assert.deepStrictEqual(Object.keys(pkg.dependencies || {}), []);
});

function runCheck(port, urlPath, version) {
  const script = path.join(__dirname, "..", "scripts", "check-ready.sh");
  return new Promise((resolve) => {
    execFile(
      "bash",
      [script, `http://127.0.0.1:${port}`, urlPath, version],
      { env: { ...process.env, CHECK_READY_SLEEP: "0" } },
      (err, stdout, stderr) => resolve({ status: err ? err.code : 0, out: stdout + stderr }),
    );
  });
}

const hasCurl = spawnSync("curl", ["--version"]).status === 0;

// The slim Cloud Build test image has no curl; this test always runs in the required GitHub check.
test("check-ready.sh passes for the right version and fails for a wrong version or path", { skip: !hasCurl && "curl not installed" }, async () => {
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, r));
  process.env.APP_VERSION = "v1";
  try {
    const port = server.address().port;
    const ok = await runCheck(port, "/ready", "v1");
    assert.strictEqual(ok.status, 0, ok.out);
    assert.notStrictEqual((await runCheck(port, "/ready", "v2")).status, 0);
    assert.notStrictEqual((await runCheck(port, "/nope", "v1")).status, 0);
  } finally {
    delete process.env.APP_VERSION;
    await new Promise((r) => server.close(r));
  }
});

test("a malformed request target returns 400 instead of crashing", async () => {
  const r = await getRaw("//[");
  assert.strictEqual(r.status, 400);
});
