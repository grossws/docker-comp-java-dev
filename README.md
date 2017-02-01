# Info

Openjdk8 [Dockerfile][df] with dev-tools for automated builds on [docker hub][dhub].

Based on `grossws/java` image.

Current toolset:

- [x] Apache Ant 1.10.0
- [x] Apache Maven 3.3.9
- [ ] Scala 2.11
- [ ] SBT
- [ ] Gradle

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
