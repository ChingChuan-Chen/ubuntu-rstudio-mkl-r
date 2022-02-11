FROM ubuntu:20.04

ENV R_VER=4.1.2 \
  CRAN_URL=https://cran.rstudio.com/


RUN apt update && apt install -y --no-install-recommends apt-transport-https ca-certificates gnupg2 gnupg-agent \
                                                software-properties-common curl apt-utils

# Add key
RUN curl --progress-bar https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB | apt-key add -
RUN echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list
RUN apt-get update && apt-get install -y intel-mkl

RUN apt-get install -y wget texlive texlive-fonts-extra texlive-latex-extra libx11-dev libpcre2-dev libjpeg-dev libpng-dev \
    libtiff-dev libxmu-dev libcurl4-openssl-dev libxt-dev libreadline-dev libcairo2-dev libpango1.0-dev libtirpc-dev \
	libncurses5-dev tcl-dev tk-dev libbz2-dev lzma-dev libgsl-dev && \
    apt-get install -y gfortran gcc g++
RUN wget --no-check-certificate -q https://cran.r-project.org/src/base/R-4/R-${R_VER}.tar.gz && \
  tar zxvf R-${R_VER}.tar.gz && \
  cd R-${R_VER} && \
  export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu && \
  export MKL_INTERFACE_LAYER=GNU,LP64 && \
  export MKL_THREADING_LAYER=GNU && \
  export MKL="-L/usr/lib/x86_64-linux-gnu -lmkl_gf_lp64 -lmkl_gnu_thread -lmkl_core -fopenmp -lpthread -ldl -lm" && \
  export CFLAGS="-std=gnu99 -g -O3 -march=native -DU_STATIC_IMPLEMENTATION" && \
  export CXXFLAGS="-g -O3 -march=native -DU_STATIC_IMPLEMENTATION" && \
  export LDFLAGS="$MKL"
  ./configure --prefix=/usr --libdir=/usr/lib/R/ --sysconfdir=/etc/R --datarootdir=/usr/share/ rsharedir=/usr/share/R/ rincludedir=/usr/include/R/ rdocdir=/usr/share/doc/R/ \
	--with-cairo --with-x --enable-R-shlib --enable-shared --enable-R-profiling --enable-BLAS-shlib --enable-memory-profiling --with-blas="$MKL" --with-lapack --with-tcltk LIBnn=lib && \
  make -j${nproc} && make install && \
  groupadd ruser && \
  chown -R root:ruser /usr/lib/R && \
  chmod -R g+w /usr/lib/R
  
# install rstudio server and config
WORKDIR /
RUN RSTUDIO_VERSION=$(wget --no-check-certificate -qO- https://s3.amazonaws.com/rstudio-server/current.ver) && \
  wget -q https://download2.rstudio.org/rstudio-server-rhel-${RSTUDIO_VERSION}-x86_64.rpm && \
  yum install --nogpgcheck -y rstudio-server-rhel-${RSTUDIO_VERSION}-x86_64.rpm && \
  printf 'Sys.setenv(PATH = paste0("/opt/rh/devtoolset-7/root/usr/bin:", Sys.getenv("PATH")),LD_LIBRARY_PATH = paste0("/opt/rh/devtoolset-7/root/usr/lib64:", Sys.getenv("LD_LIBRARY_PATH")))\n' >> /usr/lib/rstudio-server/R/ServerOptions.R && \
  printf "r-libs-user=/usr/lib64/R/library\nsession-timeout-minutes=0\\nr-cran-repos=${CRAN_URL}\n" >> /etc/rstudio/rsession.conf && \
  rm -f *.rpm

# copy rstudio-setting
COPY docker-entrypoint.sh /rstudio-server/docker-entrypoint.sh
COPY keybindings /rstudio-server/keybindings
COPY user-settings /rstudio-server/user-settings
COPY benchmark.R /rstudio-server/benchmark.R

# add user and rstudio config
RUN useradd rstudio && \
  echo "rstudio:rstudio" | chpasswd && \
  usermod -a -G ruser rstudio && \
  mkdir -p /home/rstudio/.R/rstudio/keybindings && \
  cp /rstudio-server/keybindings/*.json /home/rstudio/.R/rstudio/keybindings/ && \
  mkdir -p /home/rstudio/.rstudio/monitored/user-settings && \
  cp /rstudio-server/user-settings/* /home/rstudio/.rstudio/monitored/user-settings/ && \
  cp /rstudio-server/benchmark.R /home/rstudio && \
  chown -R rstudio: /home/rstudio

EXPOSE 8787
ENTRYPOINT ["/rstudio-server/docker-entrypoint.sh"]
CMD ["/usr/lib/rstudio-server/bin/rserver", "--server-daemonize", "0", "--rsession-which-r", "/usr/lib64/R/bin/R", "--auth-required-user-group", "ruser"]


# .RProfile
# `local` creates a new, empty environment
# This avoids polluting .GlobalEnv with the object r
local({
  r = getOption("repos")             
  r["CRAN"] = "https://cran.rstudio.com/"
  options(repos = r)
})

# .Renviron
MAKE='make -j ${nproc}'
