import argparse
import socket
import struct


def expect_payload(receiver, payload, blocked):
    receiver.settimeout(0.4 if blocked else 2)
    try:
        received = receiver.recv(len(payload), socket.MSG_WAITALL)
    except TimeoutError:
        if blocked:
            return
        raise
    if blocked or received != payload:
        raise AssertionError(f"Unexpected payload {received!r} for {payload!r}")


def test_udp(family, address, payload, blocked):
    with socket.socket(family, socket.SOCK_DGRAM) as receiver:
        receiver.bind((address, 0))
        with socket.socket(family, socket.SOCK_DGRAM) as sender:
            sender.sendto(payload, receiver.getsockname())
        expect_payload(receiver, payload, blocked)


def test_tcp(family, address, payload, blocked):
    with socket.socket(family, socket.SOCK_STREAM) as listener:
        listener.bind((address, 0))
        listener.listen()
        with socket.socket(family, socket.SOCK_STREAM) as sender:
            sender.settimeout(2)
            sender.connect(listener.getsockname())
            receiver, _ = listener.accept()
            with receiver:
                sender.sendall(payload)
                # On a normal connection, signal EOF so MSG_WAITALL can return.
                sender.shutdown(socket.SHUT_WR)
                expect_payload(receiver, payload, blocked)


parser = argparse.ArgumentParser()
parser.add_argument("--blocked", action="store_true")
args = parser.parse_args()
handshake = b"\x13BitTorrent protocol" + bytes(48)
tracker = struct.pack("!QII", 0x41727101980, 0, 1)
dht = b"d1:ad2:id20:" + b"a" * 20 + b"9:info_hash20:" + b"b" * 20 + b"e1:q9:get_peers1:t2:aa1:y1:qe"

for family, address in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
    test_tcp(family, address, b"ordinary TCP request", False)
    test_udp(family, address, b"ordinary UDP request", False)
    test_udp(family, address, b"1:q9:get_peers", False)
    test_tcp(family, address, handshake, args.blocked)
    test_udp(family, address, tracker, args.blocked)
    test_udp(family, address, dht, args.blocked)
