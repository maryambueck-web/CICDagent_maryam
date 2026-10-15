const http = require("node:http");

function handler(req, res) {
  if (req.url === "/ready") {
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(JSON.stringify({ status: "ok" }));
  }
  if (req.url === "/healthz") {
    res.writeHead(200, { "content-type": "text/plain" });
    return res.end("ok");
  }
  res.writeHead(200, { "content-type": "application/json" });
  res.end(JSON.stringify({ app: "cicdagent-sample", version: process.env.APP_VERSION || "dev" }));
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  http.createServer(handler).listen(port, () => console.log(`listening on ${port}`));
}

module.exports = { handler };
