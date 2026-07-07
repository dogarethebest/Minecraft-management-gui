const express = require("express");
const fs = require("fs");
const path = require("path");
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

const directory = path.join(
    __dirname,
    "..",
    "..",
    "mc"
);

const WHITELIST_PATH = directory
console.log(directory);

// Get whitelist
app.get("/api/whitelist", (req, res) => {

    if (!fs.existsSync(WHITELIST_PATH)) {
        return res.status(404).json({
            error: "Whitelist file not found"
        });
    }

    const whitelist = JSON.parse(
        fs.readFileSync(WHITELIST_PATH, "utf8")
    );

    res.json(whitelist);
});


// Replace whitelist
app.put("/api/whitelist", (req, res) => {

    if (!Array.isArray(req.body)) {
        return res.status(400).json({
            error: "Whitelist must be an array"
        });
    }

    fs.writeFileSync(
        WHITELIST_PATH,
        JSON.stringify(req.body, null, 2)
    );

    res.json({
        success: true
    });
});


// Add player
app.post("/api/whitelist", (req, res) => {

    if (!req.body.uuid || !req.body.name) {
        return res.status(400).json({
            error: "Missing UUID or username"
        });
    }

    let whitelist = [];

    if (fs.existsSync(WHITELIST_PATH)) {
        whitelist = JSON.parse(
            fs.readFileSync(WHITELIST_PATH, "utf8")
        );
    }


    // Prevent duplicates
    const exists = whitelist.some(
        player => player.uuid === req.body.uuid
    );

    if (exists) {
        return res.status(409).json({
            error: "Player already whitelisted"
        });
    }


    whitelist.push({
        uuid: req.body.uuid,
        name: req.body.name
    });


    fs.writeFileSync(
        WHITELIST_PATH,
        JSON.stringify(whitelist, null, 2)
    );


    res.json({
        success: true,
        player: req.body
    });
});


// Remove player
app.delete("/api/whitelist/:uuid", (req, res) => {

    if (!fs.existsSync(WHITELIST_PATH)) {
        return res.status(404).json({
            error: "Whitelist not found"
        });
    }


    let whitelist = JSON.parse(
        fs.readFileSync(WHITELIST_PATH, "utf8")
    );


    const newWhitelist = whitelist.filter(
        player => player.uuid !== req.params.uuid
    );


    fs.writeFileSync(
        WHITELIST_PATH,
        JSON.stringify(newWhitelist, null, 2)
    );


    res.json({
        success: true
    });
});