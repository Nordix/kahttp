# kahttp - Keep-alive http test program

This test program is intended for testing many simultaneous
(keep-alive) http connections. It is not intended for throughput or
latency measurements but is designed to test the limit for how many
simultaneous client connectons a http server or proxy can handle.


## Build

```
go get github.com/Nordix/mconnect
cd $GOPATH/src/github.com/Nordix/kahttp
ver=$(date +%F:%T)
CGO_ENABLED=0 GOOS=linux go install -a \
  -ldflags "-extldflags '-static' -X main.version=$ver" \
  github.com/Nordix/kahttp/cmd/kahttp
strip $GOPATH/bin/kahttp
```

## Usage

Local usage;

```
# Start server;
kahttp -server -address [::]:5080
# In another shell;
wget -q -O - http://127.0.0.1:5080/
kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nconn 40 -timeout 10s | jq .
# In yet another shell;
tcpdump -ni lo 'tcp[tcpflags] == tcp-syn'
# Or for ipv6;
tcpdump -ni lo tcp and 'ip6[13+40]&0x2!=0'
```

One way to verify that keep-alive is used done is to trace the SYN
packets with `tcpdump`. If there are an initial burst of and then
silence keep-alive is used. A steady stream os SYNs indicates that
keep-alive is not used.


Deploy a `kahttp` server on Kubernetes;
```
kubectl apply -f https://raw.githubusercontent.com/Nordix/kahttp/master/kahttp.yaml
```

NOTE: The server is very primitive and is intended for simple tests only.


## Measure keep-alive connections

`Kahttp` starts a number of http clients according to the `-nclients`
parameter. Each of these clients will make periodic http GET requests
towards the URL specified by the `-address` parameter. The `-rate`
parameter specifies the **total** number of http requests per
second. This is divided among the clients so a rate of 400 and 40
clients will result in 10 requests per second per client. The
keep-alive time is limited (but different) on servers so to make sure
connections are kept a certain rate per client must be maintained.

The key metric for measuring keep-alive connections is `Dials`. This
is the total number of actual TCP connects that the clients do. Below
is an example where all connections are kept;

```
> kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nclients 40 -timeout 10s | jq .
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 399/399/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 799/799/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 1199/1199/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 1600/1600/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 2000/2000/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 2400/2400/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 2800/2800/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 3200/3200/0
Clients act/fail/Dials: 40/0/40, Packets send/rec/dropped: 3600/3600/0
{
  "Started": "2019-04-02T13:02:06.815903366+02:00",
  "Duration": 10000112870,
  "Rate": 400,
  "Clients": 40,
  "Dials": 40,
  "FailedConnections": 0,
  "Sent": 3999,
  "Received": 3999,
  "Dropped": 0,
  "FailedConnects": 0
}
```

In this case we have 40 clients making 3999 requests in total but the
number of `Dials` is 40, so each client make only one connection which
is kept alive for the entire run.

This shows the case where there is no keep-alive;

```
> kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nclients 40 -timeout 10s | jq .
Clients act/fail/Dials: 40/0/400, Packets send/rec/dropped: 399/399/0
Clients act/fail/Dials: 40/0/800, Packets send/rec/dropped: 799/799/0
Clients act/fail/Dials: 40/0/1200, Packets send/rec/dropped: 1199/1199/0
Clients act/fail/Dials: 40/0/1600, Packets send/rec/dropped: 1599/1599/0
Clients act/fail/Dials: 40/0/2000, Packets send/rec/dropped: 1999/1999/0
Clients act/fail/Dials: 40/0/2400, Packets send/rec/dropped: 2400/2400/0
Clients act/fail/Dials: 40/0/2800, Packets send/rec/dropped: 2799/2799/0
Clients act/fail/Dials: 40/0/3200, Packets send/rec/dropped: 3200/3200/0
Clients act/fail/Dials: 40/0/3600, Packets send/rec/dropped: 3600/3600/0
{
  "Started": "2019-04-02T13:16:37.443570632+02:00",
  "Duration": 10001866073,
  "Rate": 400,
  "Clients": 40,
  "Dials": 4000,
  "FailedConnections": 0,
  "Sent": 4000,
  "Received": 4000,
  "Dropped": 0,
  "FailedConnects": 0
}
```

The number of `Dials` is equal to the number of `Sent` requests. This
means that no connection is kept alive.


## Multiple source addresses

For testing of very many connections it is essential that the
connections originates from many sources. If just one (prominent)
source is used there will likely be a shortage of connection resources
since the src/dest addresses are always the same, only the ports can
be varied. The resource problem does not have to occur on the
endpoints but can be in network elements (NE) in between such as
load-balancers or NAT boxes.

To use many source addresses you must first assign a CIDR to the
loopback interface as described for
[mconnect](https://github.com/Nordix/mconnect#many-source-addresses). Then
use;

```
kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nconn 40 \
  -timeout 10s -scrcidr 222.222.222.0/24
```
