# Docker Build and Runtime Environment for RStudio on Raspberry Pi

The Dockerfiles in this repository are used to build the RStudio Server and
Desktop Debian packages for running on the Raspberry Pi Raspbian
distribution. The work is split into a build and runtime phase where the former
is responsible for building the .deb packages and the latter is responsible
for creating a runtime environment with the RStudio Server .deb package
installed. The docker images can be either created natively on a
sufficiently potent Raspberry Pi (e.g. Raspberry Pi 3 with 1 GB of memory) or
they can be created by cross-building on an x86 host. Due to the fabulous
work of the folks at
[Balena](https://www.balena.io/docs/reference/base-images/base-images/)
cross-builds can be achieved with only a couple of lines added to the
Dockerfiles. The build phase commands are partially taken from Takahashi
Makoto's excellent write-up of [RStudio installation on Raspberry
Pi](http://herb.h.kobe-u.ac.jp/raspiinfo/rstudio_en.html).

## Building the Debian Packages
Use Dockerfile.build to create the Debian packages for RStudio Server and
Desktop. The build procedure has been adapted to the Raspbian environment
(Debian v9 Stretch) using the native version of the Boost library and the
native QT libraries.

The build process is fairly lengthy. Expect several hours (4-8ish) both
natively and in cross-build. You'll also need at least 1 GB of RAM on the
build machine, but more is better, which precludes native build on smaller
Raspberry Pis with less memory. In addition make sure to configure at least
1 GB of swap space. Under Raspbian you can configure swap space like this:
  * in `/etc/dphys-swapfile` set CONF_SWAPSIZE=1024 (default is 100)
  * run `sudo service dphys-swapfile restart`
  * once the build is done and you're happy with the result you can set
    the swap space back to the default 100 MB with:
    * in `/etc/dphys-swapfile` set CONF_SWAPSIZE=100
    * `sudo service dphys-swapfile restart`

To build run the following command:
```
docker build -f Dockerfile.build -t raspberrypi-rstudio-build .
```

To reduce the memory pressure the build uses only a parallelism of 2 by
default. If you are running out of memory you can try reducing that to 1
by adding `--build-arg BUILD_PARALLELISM=1` to the docker build command
line. On the other hand, if you are cross-building on a host with sufficient
memory you can increase this, e.g. on a host with >= 8 GB of RAM add
`--build-arg BUILD_PARALLELISM=4` to the docker build command line.

Once the build is done the Debian packages are left in the built docker
image under the path `/home/pi/Downloads/rstudio/build/\*.deb`

## Building the RStudio Server Runtime Image
Use Dockerfile.server to create the docker image that has the RStudio Server
and it's runtime environment installed. This Dockerfile makes use of
[multi-stage
build](https://docs.docker.com/develop/develop-images/multistage-build/)
to extract the Debian Server package from the build image and transplant it
into a new, leaner runtime image. You can choose to build a minimal runtime
that can run basic R programs in RStudio Server but doesn't have any extras
installed. For this you would run:
```
docker build -f Dockerfile.server --target install-minimal -t raspberrypi-rstudio-server .
```
If, on the other hand, you want a more fully featured runtime you'd run:
```
docker build -f Dockerfile.server --target install-full -t raspberrypi-rstudio-server .
```
This is also the default if you don't specify a target. The full runtime
also has the necessary system and R packages installed to support working
with .Rmd files as well as source code version control. It also contains a
compile environment for C, C++ and Fortran which is often used when you
install additional R source packages from CRAN in your R user environment.

## Running RStudio Server
Once you have the raspberrypi-rstudio-server created you can start an
RStudio server on your Raspberry Pi simply with:
```
docker run --rm --name rserver -v $PWD/work:/home/rstudio -p 8787:8787 -d raspberrypi-rstudio-server
```
The rstudio-server will start in the docker container named `rserver` and
start to listen on its default port 8787. You now simply point your web
browser to `http://<your_raspberry_pi>:8787` where you will be greeted by a
login screen.  The image is set up with a default user name of `rstudio` and
password of `raspberry`. You can override those at image build time by
adding `--build-arg USER=foo` `--build-arg PASSWORD=bar` to the command
line. After entering those credentials you will see the RStudio development
environment in your web browser.

Most likely you will want to keep the results of your work around across
container restarts. For this, the server image is expected to be used with a
working directory from your host (`$PWD/work` above) mounted into the
`/home/rstudio` directory of the `rserver` container.

## Getting the .deb Package Files
If what you want to do is not running RStudio in a Docker container but
installing them natively on your Raspberry Pi you can do that too. For this
you need to extract the .deb package files from the build image. It's a
little cumbersome, but not too much so:
```
docker create --name extract raspberrypi-rstudio-build
docker cp extract:/home/pi/Downloads/rstudio/build/rstudio-server-1.1.463-1~r2r_armhf.deb .
docker cp extract:/home/pi/Downloads/rstudio/build/rstudio--1.1.463-1~r2r_armhf.deb .
docker rm extract
```

## Installing RStudio Natively on Your Raspberry Pi
Once you have extracted the .deb images from the build container in the
steps above you're ready to install them natively on your Raspberry Pi. To
make sure the dependencies are also properly installed we'll use `apt`
instead of `dpkg` and we also update the package list first:
```
sudo apt-get update
sudo apt install ./rstudio-server-1.1.463-1~r2r_armhf.deb # installs rstudio-server
sudo apt install ./rstudio--1.1.463-1~r2r_armhf.deb  # installs rstudio-desktop
```
That's all. The Debian installation scripts have already installed the
scripts that make sure rstudio-server is started and keeps running whenever
your Raspberry Pi boots up. As for RStudio Desktop, you can find it on your
desktop in the applications menu under Programming -> RStudio.

Happy developing!
