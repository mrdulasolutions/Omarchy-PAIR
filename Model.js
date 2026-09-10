function emptyStatus() {
  return {
    ok: true,
    error: "",
    pluginId: "io.github.mrdulasolutions.pair",
    pluginVersion: "1.1.0",
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
  if (start < 0) return emptyStatus()
  try {
    var data = JSON.parse(raw.slice(start))
    var base = emptyStatus()
    if (!data || typeof data !== "object") return base
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
    var failed = emptyStatus()
    failed.ok = false
    failed.error = "Could not read PAIR status."
    failed.message = failed.error
    return failed
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
  if (busy) return { id: "busy", label: "Working…", icon: "󰂓" }
  if (status && status.updateAvailable)
    return { id: "update", label: "Update PAIR to " + status.latestVersion, icon: "󰚰" }
  return { id: "check", label: "Check for PAIR updates", icon: "󰑓" }
}
