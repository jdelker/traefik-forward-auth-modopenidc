FROM httpd
ARG MODAUTHOPENIDC_VERSION=2.4.10
ARG HTTPDCONF=httpd-openidc.conf

RUN apt update \
    && apt install -y \
        wget \
    && wget -O /tmp/package.deb https://github.com/zmartzone/mod_auth_openidc/releases/download/v${MODAUTHOPENIDC_VERSION}/libapache2-mod-auth-openidc_${MODAUTHOPENIDC_VERSION}-1.buster+1_amd64.deb \
    && apt install -y /tmp/package.deb \
    && rm /tmp/package.deb \
    && apt remove -y wget \
    && apt install -y gettext-base \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Include /tmp/${HTTPDCONF}" >> /usr/local/apache2/conf/httpd.conf

COPY conf /conf/
COPY docker-cmd.sh /docker-cmd.sh

# Default values
ENV OIDC_PROVIDER_METADATA_URL="" \
    OIDC_CLIENT_ID="" \
    OIDC_CLIENT_SECRET="" \
    OIDC_REDIRECT_URI="/modauthopenidc_redirect_uri" \
    OIDC_CRYPTO_PASSPHRASE="" \
    OIDC_SCOPE="openid email" \
    OIDC_REMOTE_USER_CLAIM="preferred_username" \
    OIDC_VHOST_EXTRA_CONFIG="" \
    OIDC_REQUIRE_CLAIM="" \
    OIDC_REQUIRE_CLAIM_1="" \
    OIDC_REQUIRE_CLAIM_2="" \
    OIDC_REQUIRE_CLAIM_3="" \
    OIDC_REQUIRE_CLAIM_4="" \
    OIDC_REQUIRE_CLAIM_5="" \
    OIDC_REQUIRE_CLAIM_6="" \
    OIDC_REQUIRE_CLAIM_7="" \
    OIDC_REQUIRE_CLAIM_8="" \
    OIDC_REQUIRE_CLAIM_9="" \
    OIDC_REQUIRE_CLAIM_10="" \
    OIDC_LOCATION_EXTRA_CONFIG=""


CMD ["/docker-cmd.sh"]
