ARG version

FROM golang:1.14 as builder
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN GO111MODULE=on CGO_ENABLED=0 \
  go build -ldflags "-s -w -extldflags '-static' -X main.version=$version" \
  -o /kahttp ./cmd/...

FROM scratch
COPY --chown=0:0 --from=builder /kahttp /
CMD ["/kahttp", "-server", "-address", ":80", "-https_addr", ":443"]
