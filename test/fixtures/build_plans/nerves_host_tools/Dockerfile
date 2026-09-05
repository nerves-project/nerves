FROM busybox:1.37

COPY nerves-artifact /usr/local/bin/nerves-artifact
RUN addgroup -S nerves \
 && adduser -S -G nerves nerves \
 && chmod +x /usr/local/bin/nerves-artifact

USER nerves
WORKDIR /workspace/build
ENTRYPOINT ["/usr/local/bin/nerves-artifact"]
CMD ["setup", "build"]
