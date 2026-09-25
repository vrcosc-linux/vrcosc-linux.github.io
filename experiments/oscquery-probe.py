#!/usr/bin/env python3
"""Host-side OSCQuery + OSC probe, run entirely OUTSIDE any wine prefix.

Answers one question: can something that is not inside VRChat's wine prefix hold
a full OSCQuery + OSC conversation with VRChat? If a plain host process can, then
so can VRCOSC running in a prefix of its own -- a wine prefix is strictly less
isolated from the host network than a separate process is, since every wine
process shares the host's network namespace.

It advertises itself the way VRCOSC does (_oscjson._tcp for the query protocol,
_osc._udp for the data port), serves the OSCQuery tree over HTTP, and prints
every OSC packet VRChat sends. With --chatbox it also sends to VRChat's port, so
both directions are observable in game.

Usage: oscquery-probe.py [--osc-port 9101] [--http-port 9102] [--chatbox TEXT]
"""
import argparse
import json
import socket
import struct
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

VRCHAT_OSC_IN = 9000  # VRChat listens here
received: dict[str, int] = {}
lock = threading.Lock()


def parse_osc(data: bytes):
    """Minimal OSC parse: returns (address, [args]) or None. Handles #bundle."""
    if data.startswith(b"#bundle"):
        out, pos = [], 16
        while pos + 4 <= len(data):
            (size,) = struct.unpack_from(">i", data, pos)
            pos += 4
            if size <= 0 or pos + size > len(data):
                break
            sub = parse_osc(data[pos : pos + size])
            if sub:
                out.append(sub)
            pos += size
        return out[0] if len(out) == 1 else (out or None)

    end = data.find(b"\0")
    if end < 0:
        return None
    address = data[:end].decode("utf-8", "replace")
    pos = (end + 4) & ~3
    args = []
    if pos < len(data) and data[pos : pos + 1] == b",":
        tend = data.find(b"\0", pos)
        tags = data[pos + 1 : tend].decode("ascii", "replace")
        pos = (tend + 4) & ~3
        for tag in tags:
            if tag == "f" and pos + 4 <= len(data):
                args.append(round(struct.unpack_from(">f", data, pos)[0], 4))
                pos += 4
            elif tag == "i" and pos + 4 <= len(data):
                args.append(struct.unpack_from(">i", data, pos)[0])
                pos += 4
            elif tag in "TF":
                args.append(tag == "T")
            elif tag == "s":
                send = data.find(b"\0", pos)
                args.append(data[pos:send].decode("utf-8", "replace"))
                pos = (send + 4) & ~3
    return address, args


def osc_message(address: str, *args) -> bytes:
    """Encode an OSC message. Supports str, float, int, bool."""

    def pad(raw: bytes) -> bytes:
        return raw + b"\0" * (4 - len(raw) % 4)

    tags, body = ",", b""
    for arg in args:
        if isinstance(arg, bool):
            tags += "T" if arg else "F"
        elif isinstance(arg, float):
            tags += "f"
            body += struct.pack(">f", arg)
        elif isinstance(arg, int):
            tags += "i"
            body += struct.pack(">i", arg)
        else:
            tags += "s"
            body += pad(str(arg).encode("utf-8") + b"\0")
    return pad(address.encode("utf-8") + b"\0") + pad(tags.encode("ascii") + b"\0") + body


class OSCQueryHandler(BaseHTTPRequestHandler):
    osc_port = 0

    def log_message(self, *_args):
        pass  # keep stdout for findings only

    def do_GET(self):
        print(f"[oscquery] VRChat fetched {self.path}", flush=True)
        if "HOST_INFO" in self.path:
            payload = {
                "NAME": "vrcosc-linux-probe",
                "OSC_IP": "127.0.0.1",
                "OSC_PORT": self.osc_port,
                "OSC_TRANSPORT": "UDP",
                "EXTENSIONS": {
                    "ACCESS": True,
                    "VALUE": True,
                    "RANGE": False,
                    "DESCRIPTION": False,
                },
            }
        else:
            # The root node must exist and advertise the branches VRChat writes to.
            payload = {
                "DESCRIPTION": "root node",
                "FULL_PATH": "/",
                "ACCESS": 0,
                "CONTENTS": {
                    "avatar": {"FULL_PATH": "/avatar", "ACCESS": 0},
                    "tracking": {"FULL_PATH": "/tracking", "ACCESS": 0},
                    "chatbox": {"FULL_PATH": "/chatbox", "ACCESS": 0},
                },
            }
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def listen_osc(port: int, stop: threading.Event):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", port))
    sock.settimeout(0.5)
    print(f"[osc] listening on UDP {port}", flush=True)
    while not stop.is_set():
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        parsed = parse_osc(data)
        if not parsed or isinstance(parsed, list):
            continue
        address, args = parsed
        with lock:
            first = address not in received
            received[address] = received.get(address, 0) + 1
        if first:
            print(f"[osc] RECV from {addr[0]}:{addr[1]}  {address} {args}", flush=True)
    sock.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osc-port", type=int, default=9101)
    ap.add_argument("--http-port", type=int, default=9102)
    ap.add_argument("--seconds", type=int, default=60)
    ap.add_argument("--chatbox", default=None, help="send this text to VRChat's chatbox")
    args = ap.parse_args()

    stop = threading.Event()
    threading.Thread(target=listen_osc, args=(args.osc_port, stop), daemon=True).start()

    OSCQueryHandler.osc_port = args.osc_port
    http = HTTPServer(("0.0.0.0", args.http_port), OSCQueryHandler)
    threading.Thread(target=http.serve_forever, daemon=True).start()
    print(f"[oscquery] HTTP on {args.http_port}", flush=True)

    # Advertise exactly the two service types VRChat's OSCQuery discovery looks for.
    publishers = [
        subprocess.Popen(
            ["avahi-publish-service", "vrcosc-linux-probe", "_oscjson._tcp", str(args.http_port)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL),
        subprocess.Popen(
            ["avahi-publish-service", "vrcosc-linux-probe", "_osc._udp", str(args.osc_port)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL),
    ]
    print("[mdns] advertising _oscjson._tcp and _osc._udp", flush=True)

    if args.chatbox:
        def send_chatbox():
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            for _ in range(args.seconds // 3):
                sock.sendto(osc_message("/chatbox/input", args.chatbox, True, False),
                            ("127.0.0.1", VRCHAT_OSC_IN))
                time.sleep(3)
        threading.Thread(target=send_chatbox, daemon=True).start()
        print(f"[osc] sending /chatbox/input to VRChat on {VRCHAT_OSC_IN}", flush=True)

    try:
        time.sleep(args.seconds)
    except KeyboardInterrupt:
        pass
    stop.set()
    for p in publishers:
        p.terminate()
    http.shutdown()

    print("\n=== RESULT ===", flush=True)
    if received:
        print(f"Received {sum(received.values())} OSC messages across {len(received)} addresses:")
        for address, count in sorted(received.items(), key=lambda kv: -kv[1])[:25]:
            print(f"  {count:6d}  {address}")
        print("\nOSC and OSCQuery work from outside any wine prefix.")
        return 0
    print("No OSC received. Either VRChat is not running, OSC is disabled in its")
    print("settings and OSCQuery discovery did not take, or mDNS is being blocked.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
