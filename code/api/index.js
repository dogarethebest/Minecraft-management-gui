const express = require("express");

const app = express();

app.set("trust proxy", "loopback");

app.use(express.json());

app.get("/api/test", (req, res) => {
    res.json({
        ip: req.ip,
        hostname: req.hostname,
        protocol: req.protocol,
        headers: req.headers
    });
});

app.listen(3001, () => {
    console.log("API running on port 3001");
});