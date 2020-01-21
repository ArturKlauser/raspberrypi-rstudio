# Deployment

Building the docker images is a time consuming process (takes several hours) and
thus isn't done on all repository pushes. Deployment is only performed upon a
push to the `deploy` branch. At that point Travis builds all docker images and
pushes them to [DockerHub](https://hub.docker.com/u/arturklauser) (see
[.travis.yml](https://github.com/ArturKlauser/raspberrypi-rstudio/blob/master/.travis.yml)).

## Steps to Follow for Deployment

* Bring the local deploy branch up to date and push it to [GitHub](https://github.com/ArturKlauser/raspberrypi-rstudio/):
  ```
  git checkout -B deploy master
  git push --force origin deploy
  ```
* This kicks off the build process on Travis. It'll build the cross product
  of:
  * Docker image stages:
    * build-env
    * server-deb
    * server
    * desktop-deb
  * Debian versions:
    * stretch
    * buster
    * bullseye

  You can [follow the build progress on Travis](https://travis-ci.org/ArturKlauser/raspberrypi-rstudio/builds).
  Expect it to take several hours. There is a chance of running into the 50
  minute per-job timeout on Travis on heavily loaded hosts. Sometimes Travis
  hosts also seem to time out on DNS queries or package installs. In those cases
  just restart the failed job and all following jobs in the Travis UI.
* If you want to create a [Github Release](https://github.com/ArturKlauser/raspberrypi-rstudio/releases) from that build:
  * Wait until the build process (above) has completed successfully and all new
    docker images are pushed to [DockerHub](https://hub.docker.com/).
  * Create a local release tag and push it to
    [GitHub](https://github.com/ArturKlauser/raspberrypi-rstudio/):
    ```
    git tag vX.Y.Z
    git push origin vX.Y.Z
    ```
  * This kicks off the release process on Travis. It'll create a draft release
    with your chosen release tag vX.Y.Z and add the Debian packages from the
    latest docker images uploaded to DockerHub. You can [follow the release
    progress on Travis](https://travis-ci.org/ArturKlauser/raspberrypi-rstudio/builds).
  * Once the draft release is done, go to the [Github Release](https://github.com/ArturKlauser/raspberrypi-rstudio/releases) page and edit it.
    * Modify the description to explain what is new in this release.
    * Publish the release to remove its draft status.
