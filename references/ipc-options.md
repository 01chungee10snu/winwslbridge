# IPC options

## Recommendation summary

Use **named pipes** for the long-term bridge on a single machine.

Use **file queue** only for prototyping, debugging, or bootstrap phases.

Use **localhost HTTP/WebSocket** only when another local consumer truly benefits from a network-shaped interface.

## Named pipe

Best fit when:
- the bridge is local to one Windows machine
- fast round trips matter
- you want to avoid touching the host network path
- the bridge host is long-lived

Pros:
- local-only by nature
- low latency
- no port allocation or firewall tuning
- clean fit for a C# bridge host

Cons:
- slightly more implementation work than file queues
- less convenient for ad hoc manual testing than HTTP

## File queue

Best fit when:
- proving a workflow before investing in a host
- debugging message shape with plain files
- surviving flaky early implementations with maximum inspectability

Pros:
- easiest to debug
- no network coupling
- resilient to partial implementation

Cons:
- slower
- awkward for frequent interactions
- easy to accumulate temp files unless cleanup is disciplined

## Localhost HTTP/WebSocket

Best fit when:
- multiple local clients need a familiar interface
- an existing local integration already assumes HTTP

Pros:
- familiar tooling
- easy manual testing with curl or browser tools
- easy extension to streaming if truly needed

Cons:
- feels like networking even when local-only
- higher risk of accidental scope creep into port, firewall, or routing discussions
- not necessary for most one-machine bridge designs

## Selection rule

If the request is about the durable architecture, recommend named pipes.
If the request is about first proof-of-concept speed, allow file queues.
If the user explicitly needs an HTTP-shaped local API, document why and keep it local-only.
