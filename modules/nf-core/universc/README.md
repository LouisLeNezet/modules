# Updating the docker container and making a new module release

Cell Ranger is a commercial tool from 10X Genomics. The container provided for the universc nf-core module is not provided nor supported by 10x Genomics. Updating the Cell Ranger or UniverSC versions in the container and publishing the update needs to be done manually.

1. Navigate to the appropriate download page. - [Cell Ranger](https://www.10xgenomics.com/support/software/cell-ranger/downloads): download the tar ball of the desired Cell Ranger version with `curl` or `wget`. Place this file in the same folder where the Dockerfile lies.

2. Edit the Dockerfile. Update the versions in these lines:

```bash
ENV CELLRANGER_VER=<VERSION>
ENV UNIVERSC_VER=<VERSION>
```

`universc.patch` adapts UniverSC to the bundled Cell Ranger version. Check it still applies, and update or drop it, when changing either version.

3. Build the container with [Wave](https://docs.seqera.io/wave), from this folder:

```bash
wave --containerfile Dockerfile --context . --platform linux/amd64 --freeze --build-repo <REPOSITORY> --await
```

4. Set the returned image as the module `container`.
