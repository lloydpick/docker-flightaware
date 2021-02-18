FROM alpine:3.13.2 as base

RUN echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories
RUN apk add --no-cache libusb ncurses-libs python3 tcl tcllib tclx tcl-tls \
  librtlsdr@testing net-tools


FROM base as build

RUN apk add --no-cache libusb-dev ncurses-dev git build-base
RUN apk add --no-cache tcl-dev autoconf python3-dev curl librtlsdr-dev@testing

ARG TCLLAUNCHER_VERSION=v1.10
ARG PIAWARE_VERSION=v3.7.2
ARG DUMP1090_VERSION=v3.7.2
ARG MLATCLIENT_VERSION=v0.2.10

RUN mkdir /tcllauncher
WORKDIR /tcllauncher

RUN curl -L --output 'tcllauncher.tar.gz' "https://github.com/flightaware/tcllauncher/archive/${TCLLAUNCHER_VERSION}.tar.gz"
RUN tar -xvf tcllauncher.tar.gz --strip-components=1
RUN autoconf -f && ./configure
RUN make && make install


RUN mkdir /piaware
WORKDIR /piaware

RUN curl -L --output 'piaware.tar.gz' "https://github.com/flightaware/piaware/archive/${PIAWARE_VERSION}.tar.gz"
RUN tar -xvf piaware.tar.gz --strip-components=1

# this has been fixed in the dev branch, but no released version with this yet
RUN sed -i "s/package require Itcl 3.4/package require Itcl/g" ./programs/piaware/faup.tcl
RUN make install


RUN mkdir /dump1090
WORKDIR /dump1090

RUN curl -L --output 'dump1090-fa.tar.gz' "https://github.com/flightaware/dump1090/archive/${DUMP1090_VERSION}.tar.gz"
RUN tar -xvf dump1090-fa.tar.gz --strip-components=1
RUN make RTLSDR=no BLADERF=no DUMP1090_VERSION="piaware-${DUMP1090_VERSION}" faup1090
RUN make test


RUN mkdir /mlatclient
WORKDIR /mlatclient

RUN curl -L --output 'mlatclient.tar.gz' "https://github.com/mutability/mlat-client/archive/${MLATCLIENT_VERSION}.tar.gz"
RUN tar -xvf mlatclient.tar.gz --strip-components=1
RUN ./setup.py install


FROM base

# tcllauncher
COPY --from=build /usr/bin/tcllauncher /usr/bin/tcllauncher
COPY --from=build /usr/lib/Tcllauncher1.10 /usr/lib/Tcllauncher1.10

# piaware bins
COPY --from=build /usr/bin/piaware-config /usr/bin/piaware-config
COPY --from=build /usr/bin/piaware-status /usr/bin/piaware-status
COPY --from=build /usr/bin/piaware /usr/bin/piaware
COPY --from=build /usr/bin/pirehose /usr/bin/pirehose

# piaware libs
COPY --from=build /usr/lib/piaware-status /usr/lib/piaware-status
COPY --from=build /usr/lib/piaware_packages /usr/lib/piaware_packages
COPY --from=build /usr/lib/pirehose /usr/lib/pirehose
COPY --from=build /usr/lib/piaware-config /usr/lib/piaware-config
COPY --from=build /usr/lib/piaware /usr/lib/piaware
COPY --from=build /usr/lib/fa_adept_codec /usr/lib/fa_adept_codec

# dump1090
COPY --from=build /dump1090/faup1090 /usr/lib/piaware/helpers/

# mlatclient bins
COPY --from=build /usr/bin/fa-mlat-client /usr/bin/fa-mlat-client
COPY --from=build /usr/bin/mlat-client /usr/bin/mlat-client
RUN ln -s /usr/bin/fa-mlat-client /usr/lib/piaware/helpers/

# mlatclient libs
COPY --from=build /usr/lib/python3.7/site-packages/_modes* /usr/lib/python3.7/site-packages/
COPY --from=build /usr/lib/python3.7/site-packages/mlat /usr/lib/python3.7/site-packages/mlat
COPY --from=build /usr/lib/python3.7/site-packages/flightaware /usr/lib/python3.7/site-packages/flightaware

COPY entrypoint.sh /
ENTRYPOINT ["./entrypoint.sh"]
