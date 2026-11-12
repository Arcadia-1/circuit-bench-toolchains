# Maintaining the images

**Updating a simulator or PDK** (for example ngspice 47 or Xyce 7.11):

1. Change the pinned source and checksum in its Dockerfile under `docker/`.
2. Publish a new base tag, then rebuild each PDK image on it with a new tag
   (major bump if simulation results can change).
3. Check the smoke tests and repeat the cross-simulator check in `validation/`.
4. Add the new digests to `images.lock.json`. Never move or delete old tags.
5. Move a task to the new image only deliberately, and re-validate it.

**Publishing**: `publish-images.yml` (ngspice, Sky130), `publish-gf180-ngspice.yml`,
`publish-analog-sim.yml` (IHP, Xyce, VACASK). Each refuses to overwrite a tag,
smoke-tests what it pushed and uploads the digests. Codeberg rate-limits the
VACASK download; `publish-analog-sim.yml` accepts a mirror URL (checksum still
enforced).
