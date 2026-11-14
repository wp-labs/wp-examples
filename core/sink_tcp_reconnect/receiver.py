#!/usr/bin/env python3
"""Minimal TCP/TLS receiver for the sink_tcp_reconnect example.

Accepts any number of connections, appends every received byte to --out, and
exits cleanly on SIGTERM/SIGINT so the test can restart it on the same port.
"""

import argparse
import os
import signal
import socket
import ssl
import sys
import threading

stop = threading.Event()
write_lock = threading.Lock()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--ready-file", default="")
    parser.add_argument("--tls-cert", default="")
    parser.add_argument("--tls-key", default="")
    return parser.parse_args()


def build_tls_context(args: argparse.Namespace):
    if not args.tls_cert:
        return None
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(args.tls_cert, args.tls_key or None)
    return ctx


def serve_conn(conn: socket.socket, out_path: str, ctx) -> None:
    try:
        if ctx is not None:
            conn = ctx.wrap_socket(conn, server_side=True)
        conn.settimeout(0.2)
        while not stop.is_set():
            try:
                chunk = conn.recv(65536)
            except socket.timeout:
                continue
            except OSError:
                break
            if not chunk:
                break
            with write_lock:
                with open(out_path, "ab") as out:
                    out.write(chunk)
                    out.flush()
    except (OSError, ssl.SSLError):
        pass
    finally:
        try:
            conn.close()
        except OSError:
            pass


def main() -> int:
    args = parse_args()
    ctx = build_tls_context(args)

    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((args.host, args.port))
    srv.listen(16)
    srv.settimeout(0.2)

    def on_stop(_signum, _frame) -> None:
        stop.set()

    signal.signal(signal.SIGTERM, on_stop)
    signal.signal(signal.SIGINT, on_stop)

    if args.ready_file:
        with open(args.ready_file, "w", encoding="utf-8") as fh:
            fh.write(str(os.getpid()))

    threads = []
    while not stop.is_set():
        try:
            conn, _ = srv.accept()
        except socket.timeout:
            continue
        except OSError:
            break
        thread = threading.Thread(target=serve_conn, args=(conn, args.out, ctx), daemon=True)
        thread.start()
        threads.append(thread)

    try:
        srv.close()
    except OSError:
        pass
    for thread in threads:
        thread.join(timeout=1.0)

    if args.ready_file:
        try:
            os.unlink(args.ready_file)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
