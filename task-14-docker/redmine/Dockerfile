FROM redmine:6.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && git clone --depth 1 --branch redmine6.0 \
        https://github.com/farend/redmine_theme_farend_bleuclair.git \
        /usr/src/redmine/themes/bleuclair \
    && rm -rf /usr/src/redmine/themes/bleuclair/.git \
    && apt-get purge -y --auto-remove git \
    && rm -rf /var/lib/apt/lists/*
