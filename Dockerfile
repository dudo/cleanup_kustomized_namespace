FROM ruby:2-slim

LABEL "name"="Kustomized Namespace - Cleanup Overlay"
LABEL "maintainer"="Brett Dudo <brett@dudo.io>"

COPY LICENSE README.md /

COPY Gemfile Gemfile.lock ./
RUN bundle install --without=development test

COPY cleanup_overlay.rb /bin/cleanup_overlay
COPY manifest.rb /bin/manifest.rb
COPY templates /bin/templates
RUN chmod +x /bin/cleanup_overlay

ENTRYPOINT ["cleanup_overlay"]
CMD ["help"]
