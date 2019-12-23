# Docker Build and Runtime Environment for RStudio on Raspberry Pi

The Dockerfiles in this repository are used to build the RStudio Server and
Desktop Debian packages for running on the Raspberry Pi Raspbian
distribution. The work is split into several phases, each of which builds a
separate docker image:
  1. Creating a build environment that contains all necessary tools to compile
     RStudio Server and Desktop and build the respective Debian packages.
     * Dockerhub: [arturklauser/raspberrypi-rstudio-build-env](https://hub.docker.com/r/arturklauser/raspberrypi-rstudio-build-env)
  2. Creating the RStudio Server Debian package within the build environment
     from 1.
     * Dockerhub: [arturklauser/raspberrypi-rstudio-server-deb](https://hub.docker.com/r/arturklauser/raspberrypi-rstudio-server-deb)
  3. Creating the RStudio Desktop Debian package within the build environment
     from 1.
     * Dockerhub: [arturklauser/raspberrypi-rstudio-desktop-deb](https://hub.docker.com/r/arturklauser/raspberrypi-rstudio-desktop-deb)
  4. Creating an RStudio Server runtime environment from 2.
     * Dockerhub: [arturklauser/raspberrypi-rstudio-server](https://hub.docker.com/r/arturklauser/raspberrypi-rstudio-server)

The docker images can be either created natively on a sufficiently potent
Raspberry Pi (e.g. Raspberry Pi 3 with 1 GB of memory) or they can be created
by cross-building on an x86 host. Due to the fabulous work of the folks at
[Balena](https://www.balena.io/docs/reference/base-images/base-images/),
cross-builds can be achieved with only a couple of lines added to the
Dockerfiles. The build phase commands are partially taken from Takahashi
Makoto's excellent write-up of [RStudio installation on Raspberry
Pi](http://herb.h.kobe-u.ac.jp/raspiinfo/rstudio_en.html).

## Before You Begin
Make sure that you have a working docker environment set up on the host machine
that you are going to use for creating or using these docker images. Please
refer to [Docker's Getting Started](https://docs.docker.com/get-started/)
documentation for setting up docker.

For docker newbies, note that docker stores the built and pulled images in its
own image cache directories by their sha256 name. Don't expect to find them in
the file system, e.g. your build directory, by image name. To list which images
you have after the build use the docker command:
```
docker images
```
Please refer to the
[docker documentation](https://docs.docker.com/engine/reference/commandline/docker/)
for basic usage of docker.

## Building the Debian Packages
Use Dockerfile.build-env to create the build environment in which the code for
RStudio Server and Desktop is going to be compiled. The build procedure has
been adapted to the Raspbian environment using the native version of the Boost
library and the native QT libraries. It has been tested on Debian 9 (Stretch)
and  Debian 10 (Buster). An experimental Debian 11 (Bullseye) version is also
available. Once the build environment is created, it is used by
Dockerfile.server-deb and Dockerfile.desktop-deb to build the RStudio Server and
Desktop Debian packages respectively.

The build process is fairly lengthy. Expect several hours (5-10ish) both
natively and in cross-build. You'll also need at least 1 GB of RAM on the build
machine, but more is better, which precludes native build on smaller Raspberry
Pis with less memory. In addition make sure to configure at least 1 GB of swap
space. Under Raspbian you can configure swap space like this:
  * in `/etc/dphys-swapfile` set CONF_SWAPSIZE=1024 (default is 100)
  * run `sudo service dphys-swapfile restart`
  * once the build is done and you're happy with the result you can set
    the swap space back to the default 100 MB:
    * in `/etc/dphys-swapfile` set CONF_SWAPSIZE=100
    * `sudo service dphys-swapfile restart`

An attempt was made to have the build run on dockerhub autobuild, but its VMs
take about 3 times longer than a native build on a Raspberry Pi 3 B+ and run
into the 4 hour time limit imposed for autobuilds. Overcoming this would have
required to split the Dockerfile.\*\-deb build files into 3 sequential builds
each, which was not considered worthwhile. So the infrastructure to hook into
dockerhub autobuilds has been removed again from this repository.

The Dockerfiles are set up for cross-build by default. To build natively, first
comment out the cross-build commands:
```
perl -i -pe 's/(.*cross-build-(start|end).*)/# $1/' docker/Dockerfile.*
```

Since the Dockerfiles depend on a number of ARGs that must be passed in on the
command line, the preferred way of building the images is to use the wrapper
shell script `build.sh`.

To build, run:
```
for stage in build-env server-deb desktop-deb; do
  ./build.sh buster "${stage}"
done
```

To reduce the memory pressure, the build uses only a parallelism of 2 by
default. If you are running out of memory you can try reducing that to 1 by
changing it in the build.sh script. On the other hand, if you are cross-building
on a host with sufficient memory you can increase this, e.g. on a host with >= 8
GB of RAM you can use `BUILD_PARALLELISM=4`.

Once the build of each Debian package is done, the build environment is
jettisoned and the packages is copied into an empty container's root directory.

## Building the RStudio Server Runtime Image
Use Dockerfile.server to create the docker image that has the RStudio Server
and it's runtime environment installed. This Dockerfile makes use of
[multi-stage
build](https://docs.docker.com/develop/develop-images/multistage-build/) to
extract the Debian Server package from the build image and transplant it into a
new lean runtime image. You can choose to build a minimal runtime that can run
basic R programs in RStudio Server but doesn't have any extras installed. For
this you would add the `--target install-minimal` to the docker build command.
The default is to build a more fully featured runtime with:
```
./build.sh buster server
```
The full runtime also has the necessary system and R packages installed to
support working with .Rmd files including latex for generating PDF, as well as
source code version control. It also contains compile environments for C, C++
and Fortran which are often used when you install additional R source packages
from CRAN in your R user environment, as well as R packages for data cleaning,
manipulation, and plotting.

## Running RStudio Server
Once you have the raspberrypi-rstudio-server created you can start an RStudio
server on your Raspberry Pi simply with:
```
docker run --rm --name rserver -v $PWD/work:/home/rstudio -p 8787:8787 -d arturklauser/raspberrypi-rstudio-server
```
The rstudio-server will start in the docker container named `rserver` and
starts to listen on its default port 8787. You now simply point your web
browser to `http://<your_raspberry_pi>:8787` where you will be greeted by a
login screen.  The image is set up with a default user name of `rstudio` and
password of `raspberry`. You can override those at image build time by adding
`--build-arg USER=foo` `--build-arg PASSWORD=bar` to the command line. After
entering those credentials you will see the RStudio development environment in
your web browser.

Most likely you will want to keep the results of your work around across
container restarts. For this, the server image is expected to be used with a
working directory from your host (`$PWD/work` above) mounted into the home
directory `/home/rstudio` of the user in the `rserver` container. Make sure that
the directory on the host exists before you pass it into the docker container,
otherwise container engine will probably create is as root which will give you
permission problems when trying to create files in it from within the container.
If you have specified a different `USER` at build time, you have to adjust the
`/home` directory accordingly.

## Getting the .deb Package Files
If you want to install and run RStudio natively on your Raspberry Pi you can do
that too. You can extract the RStudio Server Debian package from that docker
build image with:
```
docker image save arturklauser/raspberrypi-rstudio-server-deb | tar xO --wildcards '*/layer.tar' | tar x
```
This copies the `rstudio-server*.deb` package into your current directory.
Extraction of the RStudio Desktop package `rstudio-desktop*.deb` works
similarly with:
```
docker image save arturklauser/raspberrypi-rstudio-desktop-deb | tar xO --wildcards '*/layer.tar' | tar x
```
Check the [releases](https://github.com/ArturKlauser/raspberrypi-rstudio/releases)
if you just want to download some pre-built Debian packages.

## Installing RStudio Natively on Your Raspberry Pi

> ### Note for Raspbian 10 (Buster) Users
> At this time, the Raspbian Buster package archives that are configured by
> default on a fresh Raspbian install are missing a few QT5 libraries which are
> required to run RStudio Desktop. To get access to those, add the Debian package
> archive to your archive list first.
> ```
> sudo cat > /etc/apt/sources.list.d/debian.list << EOF
> deb http://deb.debian.org/debian/ buster main
> EOF
> curl -fsSL https://ftp-master.debian.org/keys/release-10.asc | sudo apt-key add -
> ```

Once you have extracted the .deb images from the build containers in the steps
above, you're ready to install them natively on your Raspberry Pi. To make sure
the dependencies are also properly installed we'll use `apt` instead of `dpkg`
and we also update the package list first:
```
sudo apt-get update
sudo apt install ./rstudio-server-1.1.463-1~r2r_armhf.deb # installs rstudio-server
sudo apt install ./rstudio--1.1.463-1~r2r_armhf.deb  # installs rstudio-desktop
```
That's all. The Debian installation scripts have already installed the scripts
that make sure rstudio-server is started and keeps running whenever your
Raspberry Pi boots up. If you point your web browser to
`http://<your_raspberry_pi>:8787` you're in the game. Note, however, that you
can't run RStudio Server both natively and in a docker container on the same
machine at the same time and have them both use the same port 8787. If you
already have a native RStudio running and using port 8787 you can map the
container version to a different port, e.g. 8788, by using `-p 8788:8787` on
the docker command line instead.

As for RStudio Desktop, you can find it on your desktop in the applications
menu under Programming -> RStudio.

Happy developing!
