FROM technojo4/luvit:alpine-latest
ADD . /app
VOLUME /app/config

WORKDIR /app
RUN lit install

WORKDIR src
ENTRYPOINT ["luvit", "./main.lua"]
