const MAGIC = [0x57, 0x4b, 0x54, 0x31];
const VERSION = 1;
const HEADER_BYTES = 20;
const FULL_FRAME = 1;
const PACKET = { hello: 1, frame: 2, event: 3, ack: 4 };
const EVENT = { key: 1, mouse: 2, paste: 3, resize: 4, focus: 5 };
const MAX_PACKET_BYTES = 16 * 1024 * 1024;
const MAX_CELLS = 4_000_000;
const MAX_STRING_BYTES = 1024 * 1024;
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

class Reader {
  constructor(buffer) { this.bytes = new Uint8Array(buffer); this.view = new DataView(buffer); this.at = 0; }
  need(count) { if (this.at + count > this.bytes.length) throw new Error("truncated WKT1 packet"); }
  u8() { this.need(1); return this.view.getUint8(this.at++); }
  u16() { this.need(2); const value = this.view.getUint16(this.at); this.at += 2; return value; }
  u32() { this.need(4); const value = this.view.getUint32(this.at); this.at += 4; return value; }
  u64() { this.need(8); const value = this.view.getBigUint64(this.at); this.at += 8; return value; }
  blob() { const size = this.u32(); if (size > MAX_STRING_BYTES) throw new Error("WKT1 field limit exceeded"); this.need(size); const value = this.bytes.slice(this.at, this.at + size); this.at += size; return value; }
  string() { return decoder.decode(this.blob()); }
}

class Writer {
  constructor() { this.bytes = []; }
  u8(value) { this.bytes.push(value & 255); }
  u16(value) { this.u8(value >>> 8); this.u8(value); }
  u32(value) { this.u8(value >>> 24); this.u8(value >>> 16); this.u8(value >>> 8); this.u8(value); }
  u64(value) { const number = BigInt(value); for (let shift = 56n; shift >= 0n; shift -= 8n) this.u8(Number((number >> shift) & 255n)); }
  blob(value) { if (value.length > MAX_STRING_BYTES) throw new Error("WKT1 field limit exceeded"); this.u32(value.length); this.bytes.push(...value); }
  string(value) { this.blob(encoder.encode(value)); }
  finish() { return new Uint8Array(this.bytes); }
}

const state = {
  socket: null, rows: 0, columns: 0, cells: [], cursor: null,
  serverSequence: null, eventSequence: 0n, cellWidth: 9, cellHeight: 18,
};
const canvas = document.querySelector("#terminal");
const shell = document.querySelector("#terminal-shell");
const context = canvas.getContext("2d", { alpha: false });
const accessible = document.querySelector("#accessible-screen");
const status = document.querySelector("#connection-status");
const light = document.querySelector("#connection-light");
const dimensions = document.querySelector("#dimensions");
const sequenceLabel = document.querySelector("#sequence");

function color(reader) {
  const kind = reader.u8(); const value = reader.u32();
  if (kind === 0) return null;
  if (kind === 1) return ["#000000", "#aa0000", "#00aa00", "#aa5500", "#0000aa", "#aa00aa", "#00aaaa", "#aaaaaa", "#555555", "#ff5555", "#55ff55", "#ffff55", "#5555ff", "#ff55ff", "#55ffff", "#ffffff"][value];
  if (kind === 2) {
    if (value < 16) return colorFromIndex(value);
    if (value < 232) { const n = value - 16; const c = [Math.floor(n / 36), Math.floor(n / 6) % 6, n % 6].map(v => v ? 55 + v * 40 : 0); return `rgb(${c.join(",")})`; }
    const gray = 8 + (value - 232) * 10; return `rgb(${gray},${gray},${gray})`;
  }
  if (kind === 3) return `#${value.toString(16).padStart(6, "0")}`;
  throw new Error("unknown WKT1 color kind");
}

function colorFromIndex(index) {
  return ["#000000", "#aa0000", "#00aa00", "#aa5500", "#0000aa", "#aa00aa", "#00aaaa", "#aaaaaa", "#555555", "#ff5555", "#55ff55", "#ffff55", "#5555ff", "#ff55ff", "#55ffff", "#ffffff"][index];
}

function style(reader) {
  const foreground = color(reader), background = color(reader), underline = color(reader);
  const modifiers = reader.u16(), linkTag = reader.u8();
  if (linkTag > 1) throw new Error("invalid WKT1 hyperlink tag");
  return { foreground, background, underline, modifiers, hyperlink: linkTag ? reader.string() : null };
}

function cell(reader) {
  const width = reader.u8(), continuation = reader.u8();
  if (continuation > 1 || (continuation && width !== 0) || (!continuation && ![1, 2].includes(width))) throw new Error("invalid WKT1 cell");
  return { width, continuation: Boolean(continuation), grapheme: reader.string(), style: style(reader) };
}

function parsePacket(buffer) {
  if (!(buffer instanceof ArrayBuffer) || buffer.byteLength < HEADER_BYTES || buffer.byteLength > MAX_PACKET_BYTES) throw new Error("invalid WKT1 packet size");
  const reader = new Reader(buffer);
  for (const byte of MAGIC) if (reader.u8() !== byte) throw new Error("invalid WKT1 magic");
  if (reader.u16() !== VERSION) throw new Error("unsupported WKT1 version");
  const kind = reader.u8(), flags = reader.u8(), sequence = reader.u64(), payloadSize = reader.u32();
  if (payloadSize !== buffer.byteLength - HEADER_BYTES) throw new Error("WKT1 payload length mismatch");
  if (kind === PACKET.hello) return parseHello(reader, flags, sequence);
  if (kind === PACKET.frame) return parseFrame(reader, flags, sequence);
  throw new Error("server sent an unsupported WKT1 packet");
}

function parseSize(reader) {
  const rows = reader.u32(), columns = reader.u32();
  if (rows * columns > MAX_CELLS) throw new Error("WKT1 viewport limit exceeded");
  return { rows, columns };
}

function parseHello(reader, flags, sequence) {
  if (flags) throw new Error("unknown WKT1 hello flags");
  const size = parseSize(reader), colorLevel = reader.u8(), capabilities = reader.u8();
  if (reader.at !== reader.bytes.length) throw new Error("trailing WKT1 hello data");
  return { kind: "hello", sequence, ...size, colorLevel, capabilities };
}

function parseFrame(reader, flags, sequence) {
  if (flags & ~FULL_FRAME) throw new Error("unknown WKT1 frame flags");
  const size = parseSize(reader), cursorTag = reader.u8();
  let cursor = null;
  if (cursorTag === 1) cursor = { row: reader.u32(), column: reader.u32(), visible: Boolean(reader.u8()), shape: reader.u8() };
  else if (cursorTag !== 0) throw new Error("invalid WKT1 cursor tag");
  const count = reader.u32();
  if (count > size.rows * size.columns || ((flags & FULL_FRAME) && count !== size.rows * size.columns)) throw new Error("invalid WKT1 frame cell count");
  const changes = [];
  for (let index = 0; index < count; index++) changes.push({ row: reader.u32(), column: reader.u32(), cell: cell(reader) });
  if (reader.at !== reader.bytes.length) throw new Error("trailing WKT1 frame data");
  return { kind: "frame", sequence, full: Boolean(flags & FULL_FRAME), ...size, cursor, changes };
}

function applyMessage(message) {
  if (state.serverSequence !== null && message.sequence !== state.serverSequence + 1n) throw new Error("WKT1 sequence gap; reconnect required");
  state.serverSequence = message.sequence;
  if (message.kind === "hello") {
    setViewport(message.rows, message.columns);
    setConnected(true, "Connected");
  } else {
    if (message.rows !== state.rows || message.columns !== state.columns) setViewport(message.rows, message.columns);
    if (message.full) state.cells.fill(null);
    for (const change of message.changes) {
      if (change.row < 1 || change.row > state.rows || change.column < 1 || change.column > state.columns) throw new Error("WKT1 cell outside viewport");
      state.cells[(change.row - 1) * state.columns + change.column - 1] = change.cell;
    }
    state.cursor = message.cursor;
    render();
  }
  sequenceLabel.textContent = `Sequence ${message.sequence}`;
  sendPacket(PACKET.ack, 0, message.sequence, new Uint8Array());
}

function setViewport(rows, columns) {
  state.rows = rows; state.columns = columns; state.cells = new Array(rows * columns).fill(null);
  dimensions.textContent = `${rows} x ${columns}`; resizeCanvas();
}

function resizeCanvas() {
  const ratio = window.devicePixelRatio || 1;
  const width = Math.max(1, shell.clientWidth - 16), height = Math.max(1, shell.clientHeight - 16);
  canvas.width = Math.floor(width * ratio); canvas.height = Math.floor(height * ratio);
  canvas.style.width = `${width}px`; canvas.style.height = `${height}px`;
  context.setTransform(ratio, 0, 0, ratio, 0, 0);
  state.cellWidth = state.columns ? width / state.columns : 9;
  state.cellHeight = state.rows ? height / state.rows : 18;
  render();
}

function render() {
  const width = canvas.clientWidth, height = canvas.clientHeight;
  context.fillStyle = "#101816"; context.fillRect(0, 0, width, height);
  const fontSize = Math.max(8, Math.min(state.cellHeight * .78, state.cellWidth * 1.55));
  context.textBaseline = "alphabetic"; context.font = `${fontSize}px "Berkeley Mono", "Iosevka", "Cascadia Code", monospace`;
  const lines = [];
  for (let row = 0; row < state.rows; row++) {
    let text = "";
    for (let column = 0; column < state.columns; column++) {
      const item = state.cells[row * state.columns + column];
      if (!item) { text += " "; continue; }
      if (item.style.background) { context.fillStyle = item.style.background; context.fillRect(column * state.cellWidth, row * state.cellHeight, state.cellWidth, state.cellHeight); }
      if (!item.continuation) {
        let foreground = item.style.foreground || "#d8e1dc";
        if (item.style.modifiers & 0x0040) foreground = item.style.background || "#101816";
        context.fillStyle = foreground; context.globalAlpha = item.style.modifiers & 0x0002 ? .58 : 1;
        context.fillText(item.grapheme, column * state.cellWidth, (row + .8) * state.cellHeight);
        context.globalAlpha = 1;
        if (item.style.modifiers & (0x0008 | 0x0010)) { context.strokeStyle = item.style.underline || foreground; context.beginPath(); context.moveTo(column * state.cellWidth, (row + .9) * state.cellHeight); context.lineTo((column + item.width) * state.cellWidth, (row + .9) * state.cellHeight); context.stroke(); }
        text += item.grapheme;
      }
    }
    lines.push(text);
  }
  if (state.cursor?.visible) { context.strokeStyle = "#e6b95f"; context.lineWidth = 1.5; context.strokeRect((state.cursor.column - 1) * state.cellWidth + 1, (state.cursor.row - 1) * state.cellHeight + 1, state.cellWidth - 2, state.cellHeight - 2); }
  accessible.textContent = lines.join("\n");
}

function packet(kind, flags, sequence, payload) {
  const writer = new Writer(); MAGIC.forEach(value => writer.u8(value)); writer.u16(VERSION); writer.u8(kind); writer.u8(flags); writer.u64(sequence); writer.u32(payload.length); writer.bytes.push(...payload); return writer.finish();
}

function sendPacket(kind, flags, sequence, payload) {
  if (state.socket?.readyState === WebSocket.OPEN) state.socket.send(packet(kind, flags, sequence, payload));
}

function sendEvent(writePayload) {
  const payload = new Writer(); writePayload(payload); sendPacket(PACKET.event, 0, state.eventSequence++, payload.finish());
}

const keyNames = { Escape: "escape", Enter: "enter", Tab: "tab", Backspace: "backspace", Delete: "delete", Insert: "insert", Home: "home", End: "end", PageUp: "pageup", PageDown: "pagedown", ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right", " ": "space" };

canvas.addEventListener("keydown", event => {
  const printable = event.key.length === 1 && !event.ctrlKey && !event.metaKey;
  const code = printable ? "character" : keyNames[event.key] || (/^F([1-9]|[1-5][0-9]|6[0-4])$/.test(event.key) ? event.key.toLowerCase() : null);
  if (!code) return; event.preventDefault();
  sendEvent(writer => { writer.u8(EVENT.key); writer.string(code); writer.string(printable ? event.key : ""); writer.u8((event.shiftKey ? 1 : 0) | (event.altKey ? 2 : 0) | (event.ctrlKey ? 4 : 0) | (event.metaKey ? 8 : 0)); writer.u8(event.repeat ? 1 : 0); writer.blob(new Uint8Array()); });
});

canvas.addEventListener("paste", event => { event.preventDefault(); const text = event.clipboardData?.getData("text/plain") || ""; sendEvent(writer => { writer.u8(EVENT.paste); writer.string(text); }); });
canvas.addEventListener("focus", () => sendEvent(writer => { writer.u8(EVENT.focus); writer.u8(1); }));
canvas.addEventListener("blur", () => sendEvent(writer => { writer.u8(EVENT.focus); writer.u8(0); }));

for (const [name, action] of [["mousedown", 0], ["mouseup", 1], ["mousemove", 2]]) canvas.addEventListener(name, event => {
  const bounds = canvas.getBoundingClientRect(), row = Math.floor((event.clientY - bounds.top) / state.cellHeight) + 1, column = Math.floor((event.clientX - bounds.left) / state.cellWidth) + 1;
  const button = event.button === 0 ? 1 : event.button === 1 ? 2 : event.button === 2 ? 3 : 0;
  sendEvent(writer => { writer.u8(EVENT.mouse); writer.u32(row); writer.u32(column); writer.u8(button); writer.u8(name === "mousemove" && event.buttons ? 3 : action); writer.u8((event.shiftKey ? 1 : 0) | (event.altKey ? 2 : 0) | (event.ctrlKey ? 4 : 0) | (event.metaKey ? 8 : 0)); writer.u8(1); });
});
canvas.addEventListener("contextmenu", event => event.preventDefault());

function sendResize() {
  if (!state.rows || !state.columns) return;
  sendEvent(writer => { writer.u8(EVENT.resize); writer.u32(state.rows); writer.u32(state.columns); });
}
new ResizeObserver(() => { resizeCanvas(); sendResize(); }).observe(shell);

function setConnected(online, message, failed = false) { status.textContent = message; light.className = `connection-light${online ? " online" : failed ? " error" : ""}`; }

function connect() {
  const requested = new URLSearchParams(location.search).get("ws");
  const url = requested || `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/wicked`;
  state.socket = new WebSocket(url, ["wicked.v1"]); state.socket.binaryType = "arraybuffer";
  state.socket.addEventListener("open", () => setConnected(false, "Negotiating"));
  state.socket.addEventListener("message", event => { try { applyMessage(parsePacket(event.data)); } catch (error) { setConnected(false, error.message, true); state.socket.close(1002, "WKT1 protocol error"); } });
  state.socket.addEventListener("close", () => setConnected(false, "Disconnected", true));
  state.socket.addEventListener("error", () => setConnected(false, "Connection failed", true));
}

connect();
