FROM base/devel

EXPOSE 80
RUN pacman-db-upgrade
RUN pacman -Syy --noconfirm python python2 gperf yasm mesa ninja nodejs git make wget

WORKDIR /root
ENV srcdir=src
RUN mkdir $srcdir

# SOURCES
RUN wget https://downloads.iridiumbrowser.de/source/iridium-browser-2018.11.71.tar.xz
RUN tar -xf iridium-browser-2018.11.71.tar.xz -C $srcdir
RUN wget https://github.com/foutrelis/chromium-launcher/archive/v6.tar.gz
RUN mv v6.tar.gz chromium-launcher-6.tar.gz
RUN tar -xzf chromium-launcher-6.tar.gz -C $srcdir
ADD chromium.desktop /root/src
ADD sandbox-linux-build.patch /root/src
ADD chromium-widevine-r2.patch /root/src
ADD python2-as-execscript.patch /root/src

ENV _google_api_key=AIzaSyDwr302FpOSkGRpLlUpPThNTDPbXcIn_FM
ENV _google_default_client_id=413772536636.apps.googleusercontent.com
ENV _google_default_client_secret=0ZChLK6AxeA3Isu96MkwqDR4


RUN pacman -S --noconfirm json-glib

# PREPARE HERE

# remove this, and change it to a variable
ADD system_libs /root/system_libs

RUN cd $srcdir/iridium-browser-2018.11.71 && cat ../chromium-widevine-r2.patch | patch --batch -Np1
RUN cd $srcdir/iridium-browser-2018.11.71 && cat ../python2-as-execscript.patch | patch --batch -Np1
RUN cd $srcdir/iridium-browser-2018.11.71 && find . -name '*.py' -exec sed -i -r 's|/usr/bin/python$|&2|g' {} +
RUN cd $srcdir/iridium-browser-2018.11.71 && find . -name '*.py' -exec sed -i -r 's|/usr/bin/env python$|&2|g' {} +
RUN cd $srcdir/iridium-browser-2018.11.71 && mkdir -p "$srcdir/python2-path"
RUN cd $srcdir/iridium-browser-2018.11.71 && ln -sf /usr/bin/python2 "$srcdir/python2-path/python"
RUN cd $srcdir/iridium-browser-2018.11.71 && mkdir -p third_party/node/linux/node-linux-x64/bin
RUN cd $srcdir/iridium-browser-2018.11.71 && ln -s /usr/bin/node third_party/node/linux/node-linux-x64/bin/
RUN cd $srcdir/iridium-browser-2018.11.71 && for _lib in $(cat /root/system_libs) libjpeg_turbo; do \
   find -type f -path "*third_party/$_lib/*" \
      \! -path "*third_party/$_lib/chromium/*" \
      \! -path "*third_party/$_lib/google/*" \
      \! -path "*base/third_party/icu/*" \
      \! -regex '.*\.\(gn\|gni\|isolate\|py\)' \
      -delete; \
  done

RUN cd $srcdir/iridium-browser-2018.11.71 && declare -rgA _system_libs=([flac]=flac [libjpeg]=libjpeg [libpng]=libpng [libwebp]=libwebp [libxml]=libxml2 [libxslt]=libxslt [re2]=re2 [snappy]=snappy [yasm]= [zlib]=minizip ) && python2 build/linux/unbundle/replace_gn_files.py --system-libraries "${!_system_libs[@]}"
RUN cd $srcdir/iridium-browser-2018.11.71 && python2 third_party/libaddressinput/chromium/tools/update-strings.py


# BUILD HERE
RUN pacman -Sy --noconfirm clang cups at-spi2-core pango libwebp libpulse atk at-spi2-atk gtk3 libxslt

RUN make -C "$srcdir/chromium-launcher-6" PREFIX=/usr
ENV PATH "$srcdir/python2-path:$PATH"
ENV TMPDIR "$srcdir/temp"
RUN cd $srcdir/iridium-browser-2018.11.71 && mkdir -p "$TMPDIR"
ADD flags /root/flags
RUN cd $srcdir/iridium-browser-2018.11.71 && python2 build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
RUN cd $srcdir/iridium-browser-2018.11.71 && python2 tools/gn/bootstrap/bootstrap.py --gn-gen-args "$(cat /root/flags)"
RUN cd $srcdir/iridium-browser-2018.11.71 && _flags=$(cat /root/flags) out/Release/gn gen out/Release --args="$(cat /root/flags)" --script-executable=/usr/bin/python2
# RUN cd $srcdir/iridium-browser-2018.11.71 && ninja -C out/Release chrome chrome_sandbox chromedriver widevinecdmadapter
CMD cd $srcdir/iridium-browser-2018.11.71 && ninja -C out/Release chrome chrome_sandbox chromedriver


# PACKAGE HERE


