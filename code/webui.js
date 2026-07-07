const express = require("express");
const path = require("path");

const app = express();
const PORT = 3000;
app.set("trust proxy", "loopback");

app.use(express.static(path.join(__dirname, "..", "gui")));

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});