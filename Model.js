function emptyStatus() {
  return {
    ok: true,
    error: "",
    pluginId: "io.github.mrdulasolutions.pair",
    pluginVersion: "1.2.4",
    installed: false,
    running: false,
    pairVersion: "",
    latestVersion: "",
    updateAvailable: false,
    arch: "",
    installRoot: "",
    hasNvidiaGpu: false,
    gpuNote: "",
    pairingNote: "",
    firewallBlocked: false,
    message: "Checking NVIDIA PAIR…",
    endpoints: { ollama: "http://127.0.0.1:11434", openai: "http://127.0.0.1:1234" },
    commands: { desktop: "", tui: "" }
  }
}

function parseStatus(text) {
  var raw = String(text || "").replace(/^\uFEFF/, "").trim()
  var start = raw.lastIndexOf("{")
  if (start < 0) return null
  try {
    var data = JSON.parse(raw.slice(start))
    var base = emptyStatus()
    if (!data || typeof data !== "object") return null
    if (String(data.pluginId || "") !== base.pluginId) return null
    base.ok = data.ok !== false
    base.error = String(data.error || "")
    base.pluginVersion = String(data.pluginVersion || base.pluginVersion)
    base.installed = data.installed === true
    base.running = data.running === true
    base.pairVersion = String(data.pairVersion || "")
    base.latestVersion = String(data.latestVersion || "")
    base.updateAvailable = data.updateAvailable === true
    base.arch = String(data.arch || "")
    base.installRoot = String(data.installRoot || "")
    base.hasNvidiaGpu = data.hasNvidiaGpu === true
    base.gpuNote = String(data.gpuNote || "")
    base.pairingNote = String(data.pairingNote || "")
    base.firewallBlocked = data.firewallBlocked === true
    base.message = String(data.message || "")
    if (data.endpoints && typeof data.endpoints === "object") {
      base.endpoints.ollama = String(data.endpoints.ollama || base.endpoints.ollama)
      base.endpoints.openai = String(data.endpoints.openai || base.endpoints.openai)
    }
    if (data.commands && typeof data.commands === "object") {
      base.commands.desktop = String(data.commands.desktop || "")
      base.commands.tui = String(data.commands.tui || "")
    }
    return base
  } catch (e) {
    return null
  }
}

function versionLabel(status) {
  if (!status || !status.installed) return "NOT INSTALLED"
  if (status.pairVersion && status.pairVersion !== "unknown")
    return "PAIR " + status.pairVersion.toUpperCase()
  return "INSTALLED"
}

function primaryAction(status, busy) {
  if (busy) return { id: "busy", label: "Working…", icon: "󰂓" }
  if (!status || !status.installed) return { id: "install", label: "Install NVIDIA PAIR", icon: "󰇚" }
  if (status.running) return { id: "launch", label: "Open PAIR", icon: "󰏌" }
  return { id: "launch", label: "Launch PAIR", icon: "󰐊" }
}

function updateAction(status, busy) {
  if (busy && status && status.updateAvailable)
    return { id: "busy", label: "Updating PAIR…", icon: "󰂓" }
  if (busy) return { id: "busy", label: "Checking GitHub…", icon: "󰂓" }
  if (status && status.updateAvailable)
    return { id: "update", label: "Update PAIR to " + status.latestVersion, icon: "󰚰" }
  return { id: "check", label: "Check for PAIR updates", icon: "󰑓" }
}

function parseNodes(text) {
  var raw = String(text || "").replace(/^\uFEFF/, "").trim()
  var start = raw.indexOf("[")
  var end = raw.lastIndexOf("]")
  if (start < 0 || end < start) return []
  try {
    var data = JSON.parse(raw.slice(start, end + 1))
    if (!data || typeof data.length !== "number") return []
    var nodes = []
    for (var i = 0; i < data.length; i++) {
      var row = data[i]
      if (!row || typeof row !== "object") continue
      nodes.push({
        name: String(row.name || row.id || "node"),
        ip: String(row.ip || row.ipAddress || ""),
        uuid: String(row.uuid || row.nodeUuid || ""),
        gpu: String(row.gpu || ""),
        local: row.local === true,
        online: row.online === true
      })
    }
    return nodes
  } catch (e) {
    return []
  }
}

function nodeTitle(node) {
  if (!node || !node.name) return "NODE"
  return String(node.name).toUpperCase()
}

function nodeMeta(node) {
  if (!node) return ""
  if (node.local) return "LOCAL"
  if (node.online) return "ONLINE"
  return "OFFLINE"
}

function nodeMetaColor(node, ok, warn, fail) {
  if (!node) return fail
  if (node.local) return node.online === false ? warn : ok
  if (node.online) return ok
  return fail
}

function nodeDetail(node) {
  if (!node) return ""
  var parts = []
  if (node.ip) parts.push(node.ip)
  if (node.gpu) parts.push(node.gpu)
  return parts.join("  ·  ")
}

function remoteOnlineCount(nodes) {
  var n = 0
  if (!nodes || typeof nodes.length !== "number") return 0
  for (var i = 0; i < nodes.length; i++) {
    if (nodes[i] && nodes[i].local !== true && nodes[i].online === true) n++
  }
  return n
}

function remoteCount(nodes) {
  var n = 0
  if (!nodes || typeof nodes.length !== "number") return 0
  for (var i = 0; i < nodes.length; i++) {
    if (nodes[i] && nodes[i].local !== true) n++
  }
  return n
}

// fail = red, warn = yellow, ok = green
function healthLevel(installed, running, error, nodes) {
  if (!installed || !running) return "fail"
  if (remoteCount(nodes) === 0 || remoteOnlineCount(nodes) === 0) return "warn"
  return "ok"
}

function healthColor(level, urgent) {
  if (level === "fail") return urgent || "#c45c5c"
  if (level === "warn") return "#d4a017"
  return "#3ea072"
}

function healthLabel(level, installed, running, nodeCount) {
  if (level === "ok") {
    if (nodeCount > 0) return "RUNNING · " + nodeCount + (nodeCount === 1 ? " NODE" : " NODES")
    return "RUNNING"
  }
  if (level === "warn") return "NO NODES"
  if (!installed) return "NOT INSTALLED"
  if (!running) return "STOPPED"
  return "FAILED"
}
