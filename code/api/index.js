const express = require("express");
const fs = require("fs");
const fsp = require("fs").promises;
const path = require("path");
const YAML = require("yaml");
const si = require("systeminformation");
const os = require("os");


const FILE = path.join(__dirname,"..","..","mc","server.properties");

const PAPER_CONFIG_PATH = path.join(
    __dirname,
    "..",
    "..",
    "mc",
    "config",
    "paper-world-defaults.yml"
);
const OPERATORS_PATH = path.join(
    __dirname,
    "..",
    "..",
    "mc",
    "ops.json"
);
const WHITELIST_PATH = path.join(
    __dirname,
    "..",
    "..",
    "mc",
    "whitelist.json"
);

console.log("Paper config path:", PAPER_CONFIG_PATH);
console.log("Operators path:", OPERATORS_PATH);
console.log("Whitelist path:", WHITELIST_PATH);
const app = express();
app.set("trust proxy", "loopback");
app.use(express.json());


// Lookup Minecraft Java UUID
async function getMinecraftUUID(username) {

    try {
        const mojang = await fetch(
            `https://api.mojang.com/users/profiles/minecraft/${username}`
        );

        if (mojang.ok) {
            const data = await mojang.json();

            return {
                uuid: data.id.replace(/-/g, ""),
                name: data.name
            };
        }
    } catch {
        console.log("Mojang API failed");
    }


    try {
        const ashcon = await fetch(
            `https://api.ashcon.app/mojang/v2/user/${username}`
        );

        if (ashcon.ok) {
            const data = await ashcon.json();

            return {
                uuid: data.uuid.replace(/-/g, ""),
                name: data.username
            };
        }

    } catch {
        console.log("Ashcon API failed");
    }


    return null;
}



// Get whitelist
app.get("/api/whitelist", (req, res) => {

    if (!fs.existsSync(WHITELIST_PATH)) {
        return res.json([]);
    }


    try {
        const whitelist = JSON.parse(
            fs.readFileSync(
                WHITELIST_PATH,
                "utf8"
            )
        );

        res.json(whitelist);

    } catch {
        res.status(500).json({
            error: "Invalid whitelist.json"
        });
    }

});

// Add player
app.post("/api/whitelist", async (req, res) => {

    const username = req.body.username;

    if (!username) {
        return res.status(400).json({
            error: "Missing username"
        });
    }


    const player = await getMinecraftUUID(username);

    if (!player) {
        return res.status(404).json({
            error: "Minecraft account not found"
        });
    }


    let whitelist = [];

    if (fs.existsSync(WHITELIST_PATH)) {

        whitelist = JSON.parse(
            fs.readFileSync(
                WHITELIST_PATH,
                "utf8"
            )
        );

    }


    const exists = whitelist.some(
        entry =>
            entry.uuid === player.uuid
    );


    if (exists) {
        return res.status(409).json({
            error: "Player already whitelisted"
        });
    }


    whitelist.push({
        uuid: player.uuid,
        name: player.name
    });


    fs.writeFileSync(
        WHITELIST_PATH,
        JSON.stringify(
            whitelist,
            null,
            2
        )
    );


    res.json({
        success: true,
        player
    });

});

// Remove player by UUID
app.delete("/api/whitelist/:uuid", (req, res) => {

    if (!fs.existsSync(WHITELIST_PATH)) {
        return res.status(404).json({
            error: "Whitelist not found"
        });
    }


    let whitelist = JSON.parse(
        fs.readFileSync(
            WHITELIST_PATH,
            "utf8"
        )
    );


    const uuid = req.params.uuid.replace(/-/g, "");


    whitelist = whitelist.filter(
        player =>
            player.uuid !== uuid
    );


    fs.writeFileSync(
        WHITELIST_PATH,
        JSON.stringify(
            whitelist,
            null,
            2
        )
    );


    res.json({
        success: true
    });

});

// Test
app.get("/api/test", (req, res) => {

    res.json({
        ip: req.ip,
        hostname: req.hostname,
        protocol: req.protocol
    });

});

// Get operators
app.get("/api/operators", (req, res) => {

    if (!fs.existsSync(OPERATORS_PATH)) {
        return res.json([]);
    }


    try {
        const operators = JSON.parse(
            fs.readFileSync(
                OPERATORS_PATH,
                "utf8"
            )
        );

        res.json(operators);

    } catch {
        res.status(500).json({
            error: "Invalid operators.json"
        });
    }

});

// Add operator
app.post("/api/operators", async (req, res) => {

    const username = req.body.username;

    if (!username) {
        return res.status(400).json({
            error: "Missing username"
        });
    }


    const player = await getMinecraftUUID(username);

    if (!player) {
        return res.status(404).json({
            error: "Minecraft account not found"
        });
    }


    let operators = [];

    if (fs.existsSync(OPERATORS_PATH)) {

        operators = JSON.parse(
            fs.readFileSync(
                OPERATORS_PATH,
                "utf8"
            )
        );

    }


    const exists = operators.some(
        entry =>
            entry.uuid === player.uuid
    );


    if (exists) {
        return res.status(409).json({
            error: "Player is already an operator"
        });
    }


    operators.push({
        uuid: player.uuid,
        name: player.name
    });


    fs.writeFileSync(
        OPERATORS_PATH,
        JSON.stringify(
            operators,
            null,
            2
        )
    );


    res.json({
        success: true,
        player
    });

});

// Remove operator by UUID
app.delete("/api/operators/:uuid", (req, res) => {

    if (!fs.existsSync(OPERATORS_PATH)) {
        return res.status(404).json({
            error: "Operators file not found"
        });
    }


    let operators = JSON.parse(
        fs.readFileSync(
            OPERATORS_PATH,
            "utf8"
        )
    );


    const uuid = req.params.uuid.replace(/-/g, "");


    operators = operators.filter(
        player =>
            player.uuid !== uuid
    );


    fs.writeFileSync(
        OPERATORS_PATH,
        JSON.stringify(
            operators,
            null,
            2
        )
    );


    res.json({
        success: true
    });

});

app.get("/api/antixray", (req, res) => {

    if (!fs.existsSync(PAPER_CONFIG_PATH)) {
        return res.status(404).json({
            error: "paper-world-defaults.yml not found"
        });
    }

    try {
        const config = YAML.parse(
            fs.readFileSync(PAPER_CONFIG_PATH, "utf8")
        );

        res.json({
            enabled: !!config.anticheat?.["anti-xray"]?.enabled
        });

    } catch (err) {
        res.status(500).json({
            error: "Failed to read Paper configuration"
        });
    }

});

app.put("/api/antixray", (req, res) => {

    if (typeof req.body.enabled !== "boolean") {
        return res.status(400).json({
            error: "enabled must be true or false"
        });
    }

    if (!fs.existsSync(PAPER_CONFIG_PATH)) {
        return res.status(404).json({
            error: "paper-world-defaults.yml not found"
        });
    }

    try {

        const config = YAML.parse(
            fs.readFileSync(PAPER_CONFIG_PATH, "utf8")
        );

        if (!config.anticheat) {
            config.anticheat = {};
        }

        if (!config.anticheat["anti-xray"]) {
            config.anticheat["anti-xray"] = {};
        }

        config.anticheat["anti-xray"].enabled = req.body.enabled;

        fs.writeFileSync(
            PAPER_CONFIG_PATH,
            YAML.stringify(config)
        );

        res.json({
            success: true,
            enabled: req.body.enabled
        });

    } catch (err) {

        res.status(500).json({
            error: "Failed to update Paper configuration"
        });

    }

});

async function readProperties() {
    const text = await fsp.readFile(FILE, "utf8");

    const props = {};

    for (const line of text.split("\n")) {
        const trimmed = line.trim();

        if (
            trimmed === "" ||
            trimmed.startsWith("#")
        ) continue;

        const index = trimmed.indexOf("=");

        const key = trimmed.substring(0, index);
        const value = trimmed.substring(index + 1);

        props[key] = value;
    }

    return props;
}

async function writeProperties(properties) {
    const original = await fsp.readFile(FILE, "utf8");

    const lines = original.split("\n");

    const output = lines.map(line => {
        if (line.startsWith("#") || !line.includes("="))
            return line;

        const index = line.indexOf("=");
        const key = line.substring(0, index);

        if (!(key in properties))
            return line;

        return `${key}=${properties[key]}`;
    });

    await fsp.writeFile(FILE, output.join("\n"));
}

app.get("/api/server/properties", async (req, res) => {
    res.json(await readProperties());
});

app.get("/api/server/properties/:key", async (req, res) => {
    const props = await readProperties();

    if (!(req.params.key in props))
        return res.status(404).json({
            error: "Unknown property"
        });

    res.json({
        key: req.params.key,
        value: props[req.params.key]
    });
});

app.put("/api/server/properties/:key", async (req, res) => {
    const props = await readProperties();

    if (!(req.params.key in props))
        return res.status(404).json({
            error: "Unknown property"
        });

    const oldValue = props[req.params.key];
    props[req.params.key] = String(req.body.value);

    await writeProperties(props);

    res.json({
        success: true,
        oldValue,
        newValue: props[req.params.key]
    });
});

app.patch("/api/server/properties", async (req, res) => {
    const props = await readProperties();

    const updated = [];

    for (const [key, value] of Object.entries(req.body)) {
        if (key in props) {
            props[key] = String(value);
            updated.push(key);
        }
    }

    await writeProperties(props);

    res.json({
        success: true,
        updated
    });
});

console.log(
    app.router.stack
        .filter(layer => layer.route)
        .map(layer => ({
            method: Object.keys(layer.route.methods)[0].toUpperCase(),
            path: layer.route.path
        }))
);

app.listen(3001, "127.0.0.1", () => {
    console.log("Minecraft API running on port 3001");
});