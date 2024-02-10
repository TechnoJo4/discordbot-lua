FROM alpine:latest AS build
RUN apk add -U git build-base cmake perl linux-headers

WORKDIR /src
RUN git clone --recursive https://github.com/luvit/luvi.git

# build luvi
WORKDIR luvi
RUN make regular-asm
RUN make
RUN make test

# build lit
ADD https://lit.luvit.io/packages/luvit/lit/latest.zip lit.zip
RUN build/luvi lit.zip -- make lit.zip build/lit build/luvi

# build luvit
WORKDIR build
RUN ./lit make luvit/luvit luvit luvi

# base luvit-only image
FROM alpine:latest AS luvit
RUN apk add -U libgcc
COPY --from=build /src/luvi/build/* /bin/

# discordbot-lua2 image
FROM luvit
ADD . /app
VOLUME /app/config

WORKDIR /app
RUN lit install

WORKDIR src
ENTRYPOINT ["luvit", "./main.lua"]
