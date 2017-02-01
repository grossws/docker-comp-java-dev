# Info

Openjdk8 [Dockerfiles][df] with dev-tools for automated builds on [docker hub][dhub].

Based on `grossws/java` image.

Is part of the [docker-components][dcomp] repo.

# Usage

```bash
docker run --rm -it -v /path/to/project:/app -v /path/to/.m2:/app/.m2 grossws/java-dev
# in container:
mvn clean test package verify
# or
ant
```

[df]: http://docs.docker.com/reference/builder/ "Dockerfile reference"
[dhub]: https://hub.docker.com/u/grossws/
[dcomp]: https://github.com/grossws/docker-components


# Licensing

Licensed under MIT License. See [LICENSE file](LICENSE)
