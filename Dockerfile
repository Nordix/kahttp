FROM scratch
COPY --chown=0:0 image/ /
CMD ["/kahttp", "-server", "-address", ":80", "-https_addr", ":443"]
