FROM ruby:2-slim

LABEL "name"="Kustomized Namespace Action - Cleanup Overlay"
LABEL "maintainer"="Brett Dudo <brett@dudo.io>"
LABEL "version"="1.0.0"

LABEL "com.github.actions.icon"="trash"
LABEL "com.github.actions.color"="red"
LABEL "com.github.actions.name"="Kustomized Namespace - Cleanup Overlay"
LABEL "com.github.actions.description"="This deletes an overlay, and associated files"
# COPY LICENSE README.md THIRD_PARTY_NOTICE.md /

COPY Gemfile Gemfile.lock ./
RUN bundle install --without=development test

COPY cleanup_overlay.rb /bin/cleanup_overlay
COPY manifest.rb /bin/manifest.rb
COPY templates /bin/templates
RUN chmod +x /bin/cleanup_overlay

ENTRYPOINT ["cleanup_overlay"]
CMD ["help"]
