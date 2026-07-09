const endpoints = {
    health: "/api/test",
    whitelist: "/api/whitelist",
    operators: "/api/operators",
    status: "/api/status",
    metrics: "/api/metrics",
    properties: "/api/properties",
    backups: "/api/backups",
    terminalSocket: `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/api/terminal`,
    terminalCommand: "/api/terminal/command"
};

const state = {
    activeTab: "whitelist",
    whitelist: [],
    operators: [],
    filter: ""
};

function $(selector, root = document) {
    return root.querySelector(selector);
}

function $all(selector, root = document) {
    return [...root.querySelectorAll(selector)];
}

function setActiveNav() {
    const file = location.pathname.split("/").pop() || "index.html";
    $all(".nav-link").forEach((link) => {
        const target = link.getAttribute("href") || "index.html";
        link.classList.toggle("active", target === file || (file === "" && target === "index.html"));
    });
}

function setText(id, value) {
    const element = document.getElementById(id);
    if (element) element.textContent = value;
}

function setPill(id, text, className) {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = text;
    element.className = `pill ${className}`;
}

function formatUuid(uuid) {
    const clean = (uuid || "").replace(/-/g, "");
    if (clean.length !== 32) return uuid || "Unknown";
    return `${clean.slice(0, 8)}-${clean.slice(8, 12)}-${clean.slice(12, 16)}-${clean.slice(16, 20)}-${clean.slice(20)}`;
}

function avatar(uuid) {
    return `https://crafatar.com/avatars/${(uuid || "").replace(/-/g, "")}?size=80&overlay`;
}

function showMessage(text, type = "info") {
    const message = document.getElementById("message");
    if (!message) return;
    message.textContent = text;
    message.className = `message show ${type}`;
}

function clearMessage() {
    const message = document.getElementById("message");
    if (!message) return;
    message.className = "message";
    message.textContent = "";
}

function setLoading(isLoading) {
    $all("button[data-load-lock]").forEach((button) => {
        button.disabled = isLoading;
    });
}

async function request(path, options) {
    const response = await fetch(path, {
        headers: { "Content-Type": "application/json" },
        ...options
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
    return payload;
}

async function optionalRequest(path) {
    try {
        return await request(path);
    } catch (error) {
        return { unavailable: true, error: error.message };
    }
}

async function checkApi() {
    const result = await optionalRequest(endpoints.health);
    const online = !result.unavailable;
    setText("apiStatusText", online ? "OK" : "Off");
    setPill("apiStatusPill", online ? "Online" : "Offline", online ? "online" : "warn");
    setText("apiHost", online ? (result.hostname || location.hostname) : "Unavailable");
    setText("apiProtocol", online ? (result.protocol || location.protocol.replace(":", "")) : "Unknown");
}

async function loadPlayers() {
    const tableBody = document.getElementById("playersBody");
    if (!tableBody && !document.getElementById("whitelistCount")) return;

    try {
        const [whitelist, operators] = await Promise.all([
            request(endpoints.whitelist),
            request(endpoints.operators)
        ]);
        state.whitelist = Array.isArray(whitelist) ? whitelist : [];
        state.operators = Array.isArray(operators) ? operators : [];
        setText("whitelistCount", state.whitelist.length);
        setText("operatorCount", state.operators.length);
        setText("totalManagedCount", new Set([...state.whitelist, ...state.operators].map((player) => player.uuid)).size);
        renderPlayers();
    } catch (error) {
        setText("whitelistCount", "—");
        setText("operatorCount", "—");
        if (tableBody) tableBody.innerHTML = `<tr><td class="empty" colspan="4">Unable to load player lists. ${error.message}</td></tr>`;
    }
}

function renderPlayers() {
    const tableBody = document.getElementById("playersBody");
    if (!tableBody) return;

    const rows = state[state.activeTab].filter((player) => `${player.name || ""} ${player.uuid || ""}`.toLowerCase().includes(state.filter));
    if (rows.length === 0) {
        tableBody.innerHTML = `<tr><td class="empty" colspan="4">No ${state.activeTab} players found.</td></tr>`;
        return;
    }

    tableBody.innerHTML = rows.map((player) => `
        <tr>
            <td><div class="player"><img class="avatar" src="${avatar(player.uuid)}" alt=""><span>${player.name || "Unknown"}</span></div></td>
            <td class="uuid">${formatUuid(player.uuid)}</td>
            <td><span class="pill ${state.activeTab === "operators" ? "info" : "online"}">${state.activeTab === "operators" ? "Operator" : "Whitelisted"}</span></td>
            <td><button class="btn btn-danger" type="button" data-load-lock data-remove="${state.activeTab}" data-uuid="${player.uuid}">Remove</button></td>
        </tr>`).join("");
}

function wirePlayersPage() {
    const form = document.getElementById("playerForm");
    if (!form) return;

    form.addEventListener("submit", async (event) => {
        event.preventDefault();
        const action = event.submitter.dataset.action;
        const username = $("#username").value.trim();
        if (!username) return;
        setLoading(true);
        clearMessage();
        try {
            const result = await request(endpoints[action], {
                method: "POST",
                body: JSON.stringify({ username })
            });
            showMessage(`${result.player.name} added to ${action === "operators" ? "operators" : "whitelist"}.`, "success");
            $("#username").value = "";
            await loadPlayers();
        } catch (error) {
            showMessage(error.message, "error");
        } finally {
            setLoading(false);
        }
    });

    $("#refreshButton")?.addEventListener("click", loadPlayers);
    $("#search")?.addEventListener("input", (event) => {
        state.filter = event.target.value.toLowerCase();
        renderPlayers();
    });

    $all(".tab").forEach((tab) => tab.addEventListener("click", () => {
        state.activeTab = tab.dataset.tab;
        $all(".tab").forEach((item) => item.classList.toggle("active", item === tab));
        renderPlayers();
    }));

    $("#playersBody")?.addEventListener("click", async (event) => {
        const button = event.target.closest("[data-remove]");
        if (!button) return;
        setLoading(true);
        clearMessage();
        try {
            await request(`${endpoints[button.dataset.remove]}/${button.dataset.uuid}`, { method: "DELETE" });
            showMessage("Player removed.", "success");
            await loadPlayers();
        } catch (error) {
            showMessage(error.message, "error");
        } finally {
            setLoading(false);
        }
    });
}

async function loadDashboardExtras() {
    if (!document.getElementById("serverStatus")) return;
    const [status, metrics, backups] = await Promise.all([
        optionalRequest(endpoints.status),
        optionalRequest(endpoints.metrics),
        optionalRequest(endpoints.backups)
    ]);

    setText("serverStatus", status.unavailable ? "Unknown" : (status.status || status.state || "Online"));
    setText("playerOnlineCount", metrics.unavailable ? "—" : (metrics.playersOnline ?? metrics.onlinePlayers ?? metrics.players ?? "—"));
    setText("memoryUsage", metrics.unavailable ? "—" : (metrics.memory || metrics.ram || "—"));
    setText("lastBackup", backups.unavailable ? "Not connected" : (backups.latest || backups.lastBackup || "No backups reported"));
}

function wireMapPage() {
    const frame = document.getElementById("mapFrame");
    if (!frame) return;
    const params = new URLSearchParams(location.search);
    const mapUrl = params.get("src") || localStorage.getItem("mapUrl") || "/map/";
    frame.src = mapUrl;
    $("#mapUrl")?.setAttribute("value", mapUrl);
    $("#openMap")?.setAttribute("href", mapUrl);
    $("#mapForm")?.addEventListener("submit", (event) => {
        event.preventDefault();
        const value = $("#mapUrl").value.trim() || "/map/";
        localStorage.setItem("mapUrl", value);
        frame.src = value;
        $("#openMap").setAttribute("href", value);
    });
}

function writeTerminal(term, line) {
    if (term) term.writeln(line);
    const fallback = document.getElementById("terminalFallback");
    if (fallback) fallback.value += `${line}\n`;
}

function wireTerminalPage() {
    if (!document.getElementById("terminal")) return;
    let term;
    let socket;

    if (window.Terminal) {
        term = new window.Terminal({
            cursorBlink: true,
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
            theme: { background: "#020617", foreground: "#bbf7d0" }
        });
        term.open(document.getElementById("terminal"));
        document.getElementById("terminalFallback")?.remove();
    }

    writeTerminal(term, "Minecraft console ready. Connecting to /api/terminal ...");

    function connect() {
        if (!window.WebSocket) {
            writeTerminal(term, "WebSocket is not supported in this browser.");
            return;
        }
        socket = new WebSocket(endpoints.terminalSocket);
        socket.addEventListener("open", () => {
            setPill("terminalStatus", "Connected", "online");
            writeTerminal(term, "Connected to terminal stream.");
        });
        socket.addEventListener("message", (event) => writeTerminal(term, event.data));
        socket.addEventListener("close", () => {
            setPill("terminalStatus", "Disconnected", "warn");
            writeTerminal(term, "Terminal socket closed. The API may not expose /api/terminal yet.");
        });
        socket.addEventListener("error", () => {
            setPill("terminalStatus", "Unavailable", "danger");
            writeTerminal(term, "Unable to connect to the terminal socket.");
        });
    }

    connect();

    document.getElementById("commandForm")?.addEventListener("submit", async (event) => {
        event.preventDefault();
        const input = document.getElementById("commandInput");
        const command = input.value.trim();
        if (!command) return;
        writeTerminal(term, `> ${command}`);
        input.value = "";
        if (socket && socket.readyState === WebSocket.OPEN) {
            socket.send(command);
            return;
        }
        try {
            await request(endpoints.terminalCommand, {
                method: "POST",
                body: JSON.stringify({ command })
            });
        } catch (error) {
            writeTerminal(term, `Command API unavailable: ${error.message}`);
        }
    });

    document.getElementById("reconnectTerminal")?.addEventListener("click", () => {
        if (socket) socket.close();
        connect();
    });
}

async function init() {
    setActiveNav();
    await Promise.all([checkApi(), loadPlayers(), loadDashboardExtras()]);
    wirePlayersPage();
    wireMapPage();
    wireTerminalPage();
}

init();
