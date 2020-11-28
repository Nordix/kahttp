# kahttp - Keep-alive http test program

This test program is intended for testing many simultaneous
(keep-alive) http connections. It is not intended for throughput or
latency measurements but is designed to test the limit for how many
simultaneous client connectons a http server or proxy can handle.


## Build

```
./build.sh image
ls ./image/kahttp
```

## Usage

Local usage;

```
# Start server;
kahttp -server -address [::]:5080
# In another shell;
wget -q -O - http://127.0.0.1:5080/
kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nclients 40 -timeout 10s | jq .
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

The server will use an internal self-signed certificate for https by
default. See below for an instruction howto use a k8s tls secret.


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

This shows the case where keep-alive is disabled using the
`-disable_ka` flag;

```
# kahttp -nclients 10 -monitor -address https://10.0.0.2/ -host_stats -disable_ka | jq .
Clients act/fail/Dials: 10/0/10, Packets send/rec/dropped: 10/10/0
Clients act/fail/Dials: 10/0/20, Packets send/rec/dropped: 20/20/0
Clients act/fail/Dials: 10/0/30, Packets send/rec/dropped: 30/30/0
Clients act/fail/Dials: 10/0/40, Packets send/rec/dropped: 40/40/0
Clients act/fail/Dials: 10/0/50, Packets send/rec/dropped: 50/50/0
Clients act/fail/Dials: 10/0/60, Packets send/rec/dropped: 60/60/0
Clients act/fail/Dials: 10/0/70, Packets send/rec/dropped: 70/70/0
Clients act/fail/Dials: 10/0/80, Packets send/rec/dropped: 80/80/0
Clients act/fail/Dials: 10/0/90, Packets send/rec/dropped: 90/90/0
{
  "Started": "2019-04-06T08:18:09.44414217Z",
  "Duration": 9897737610,
  "Rate": 10,
  "Clients": 10,
  "Dials": 100,
  "FailedConnections": 0,
  "Sent": 100,
  "Received": 100,
  "Dropped": 0,
  "FailedConnects": 0,
  "Hosts": {
    "kahttp-deployment-ff8b6966-2cjw6": 26,
    "kahttp-deployment-ff8b6966-j45fw": 24,
    "kahttp-deployment-ff8b6966-plvqn": 26,
    "kahttp-deployment-ff8b6966-t867d": 24
  }
}
```

The number of `Dials` is equal to the number of `Sent` requests. This
means that no connection is kept alive.

### Server host statistics

The example above uses the `-host_stats` to get server host
statistics. Server host statistics only works if the server is
`kahttp`. The `kahttp` server returns the hostname of the server in
the body and in the `X-Kahttp-Server-Host:` http header. The `kahttp`
client collect the statistics and presents the number of requests to
each host.

This functions is not usable for keep-alive testing (the main purpose
of `kahttp`) but may be used for instance to test a
[canary](https://github.com/heptio/contour/blob/master/docs/ingressroute.md#upstream-weighting)
setup. When `-host_stats` is used you should most likely also disable
keep-alive with `-disable_ka`.


### Server access logging

Access to the server can be logged (to stdout). This may be useful for
debugging and tests of low intensity traffic such as health probing.

**NOTE:** Extensive logging will affect performance.

Server access logging is initiated with the `-log-access` parameter or
the `$LOG_ACCESS` environment variable. The parameter specifies a
sub-path to be logged or "/" to log everything.

```
$ ./image/kahttp -server -address :7000 -log-access /metrics
2020-07-11 13:02:39; localhost:7000/metrics from 127.0.0.1:43660
2020-07-11 13:02:39; localhost:7000/metrics from 127.0.0.1:43662
2020-07-11 13:02:39; localhost:7000/metrics from 127.0.0.1:43664
...
```

The log format is "date; <host/path> from <remote_addr>".


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
kahttp -address http://127.0.0.1:5080/ -monitor -rate 400 -nclients 40 \
  -timeout 10s -scrcidr 222.222.222.0/24
```

## Set source address

Some times the source address must be set for instance to use a
specific ip-family as described in [#6](https://github.com/Nordix/kahttp/issues/6).

The `-scrcidr` can be used for this purpose but with masks /32 and /128;

```
$ kahttp kahttp -address http://vm-001/cgi-bin/info -monitor -timeout 5s -srccidr 192.168.1.3/32
... (ipv4 used)
$ kahttp kahttp -address http://vm-001/cgi-bin/info -monitor -timeout 5s -srccidr 1000::1:c0a8:103/128
... (ipv6 used)
```

## Https

`Kahttp` disables certificate verification because the server is most
likely using a self-signed certificate. There is currently no way of
enabling certificate verification in the `kahttp` client.

The `kahttp` server will expose a https server if *both* `-https_key`
and `-https_cert` are specified (or the corresponding environment
variables $KAHTTP_KEY and $KAHTTP_CERT are set). The address
(including the port) can be specified with the `-https_addr` option
(default ":5443").

Implementation is based on [this](https://github.com/denji/golang-tls)
description.

Example;
```
export KAHTTP_KEY=/tmp/server.key
export KAHTTP_CERT=/tmp/server.crt
openssl genrsa -out $KAHTTP_KEY 2048
openssl req -new -x509 -sha256 -key $KAHTTP_KEY -out $KAHTTP_CERT -days 3650
kahttp -server -address [::]:5080
# In another shell;
wget --no-check-certificate -qO- https://[::1]:5443/
# Or;
kahttp -address https://[::1]:5443/ -monitor -rate 400 -nclients 40 -timeout 10s | jq .
```

If you use another client, e.g. `curl` you can verify the self-signed
certificate. First the "Common name" used must match the request
url. Use the `--resolv` option, for example;

```
curl -v --cacert /tmp/server.crt --resolv kahttp.localdomain:5443:[::1] \
  https://kahttp.localdomain:5443/
```

### Client certificate, mTLS

Kahttp accepts and verifies client certificates if given
(`tls.VerifyClientCertIfGiven`). Http requests without client
certificate or with a correct certificate are accepted but requests
with an invalid certificate are rejected.

```
curl -v --cacert /tmp/server.crt --resolv kahttp.localdomain:5443:[::1] \
  --cert /tmp/server.crt --key /tmp/server.key \
  https://kahttp.localdomain:5443/
...
* TLSv1.2 (OUT), TLS handshake, CERT verify (15):
```

The same certificate as for the server is presented as a client
certificate which is valid and the (faked) header
`CERT verify` indicates that a client certificate is used.

If an invalid client certificate is used the conneciton fails;

```
curl --cacert /tmp/server.crt --resolv kahttp.localdomain:5443:[::1] \
  --cert /tmp/kahttp.crt --key /tmp/kahttp.key \
  https://kahttp.localdomain:5443/
...
curl: (35) error:14094412:SSL routines:ssl3_read_bytes:sslv3 alert bad certificate
```

### Http2

Curl uses http/2 by default, use the `--http1.1` option to enforce
http1. Use the `-http2` flag to make the `kahttp` client to use
http2. Http2 used on a clear-text connection (http) is converted to h2c.

```
curl --insecure --http1.1 --resolv kahttp.localdomain:5443:[::1] https://[::1]:5443/

kahttp -address https://[::1]:5443/ -monitor -http2 -rate 400 -nclients 40 -timeout 10s | jq .

# This will use h2c;
kahttp -address http://[::1]:5443/ -http2
```

### Use a k8s tls secret

First create a k8s tls secret from the crt and key files;

```
kubectl create secret tls kahttp-secret --key /cert/kahttp.key --cert /cert/kahttp.crt
```

In the kahttp manifest mount the secret and set the KAHTTP_KEY and
KAHTTP_CERT variables appropriately (see
[kahttp-secret.yaml](kahttp-secret.yaml));

```
...
        env:
          - name: KAHTTP_KEY
            value: "/cert/tls.key"
          - name: KAHTTP_CERT
            value: "/cert/tls.crt"
        volumeMounts:
          - name: cert
            mountPath: "/cert"
            readOnly: true
      volumes:
        - name: cert
          secret:
            secretName: kahttp-secret
```
