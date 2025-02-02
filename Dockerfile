FROM golang:1.22-alpine AS builder
WORKDIR /app
ARG TARGETARCH 
RUN apk --no-cache --update add build-base gcc wget unzip
COPY . .
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -o build/x-ui main.go
RUN chmod +x DockerInitFiles.sh
RUN ./DockerInitFiles.sh "$TARGETARCH"

FROM alpine
ENV TZ=Asia/Shanghai
WORKDIR /app

RUN apk add ca-certificates tzdata

COPY --from=builder  /app/build/ /app/
VOLUME [ "/etc/x-ui" ]
CMD [ "./x-ui" ]