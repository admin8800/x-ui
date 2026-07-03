FROM golang:1.26-alpine AS builder
WORKDIR /app
ARG TARGETARCH 
RUN apk --no-cache --update add build-base gcc wget unzip
COPY . .
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -ldflags "-w -s" -o build/x-ui main.go
RUN ./DockerInitFiles.sh "$TARGETARCH"

FROM alpine
ENV TZ=Asia/Shanghai
WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata libcap nftables

COPY --from=builder /app/build/ /app/

VOLUME [ "/etc/x-ui" ]
CMD [ "./x-ui" ]
