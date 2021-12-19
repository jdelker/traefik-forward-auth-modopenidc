## traefik-forward-auth-modopenidc

A Docker image for a forwardauth container based on the `mod_auth_openidc` Apache 2.x module.
This image is meant to serve in conjunction with Traefik and other compatible reverse proxies.

- [Why this image exists](#why-this-image-exists)
- [Quickstart](#quickstart)
- [Available ENVs / Claims configuration](#available-envs--claims-configuration)
  - [Arbitrary additional configuration](#arbitrary-additional-configuration)
- [`mod_auth_openidc` headers](#mod_auth_openidc-headers)
  - [Debugging headers](#debugging-headers)
- [Examples](#examples)

# Why this image exists

This is a slightly modified fork of [whefter's docker-mod-auth-openidc-forwardauth](https://github.com/whefter/docker-mod-auth-openidc-forwardauth), which just contains some minor improvements and cleanup.
I share his requirement for a more sophisticated method to authorize users via OpenID. Except the build-in [OpenID Connect Authentication](https://doc.traefik.io/traefik-enterprise/middlewares/oidc/) of Traefik Enterprise, I'm not aware of any other free forard-auth module, to authorize against OpenID claims, rather than individual user whitelists.

Using a full Apache HTTP setup, combined with mod_auth_openidc for this task, is somewhat overkill for my taste. However, it actually provides a solution to the problem. I would rather use a leaner approach like [Thom Seddon's traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth), but enhancing that for claim authorization would require skills in GO, which I unfortunately don't have.

Besides the requirement to specify flexible claim requirements, I would rather like to use a single forward-auth instance for all container authorizations. Currently, you will require a distinct instance of this provider for each claim requirement, because the authorization configuration is static in the underlying httpd configuration.
I could thing of smarter ways to do that (like providing the claim requirements via query-params on the forwardauth.address URL), but unfortunately that isn't possible with httpd's rather static configuration.

# Quickstart

Here is an example `docker-compose.yml` based on a Keycloak OpenID Connect provider:

```yaml
version: "3.8"

networks:
  app: {}

services:
  traefik:
    image: traefik:v2.5
    networks:
      - app
    command:
      - "--log.level=DEBUG"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.constraints=Label(`traefik.tags`,`modauthopenidc-example`)"
      - "--entrypoints.web.address=:80"
    ports:
      - 80:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  forwardauth:
    image: delker/mod-auth-openidc-forwardauth
    networks:
      - app
    environment:
      OIDC_PROVIDER_METADATA_URL: https://keycloak.example.com/auth/realms/modauthopenidctest/.well-known/openid-configuration
      OIDC_CLIENT_ID: client-id
      OIDC_CLIENT_SECRET: client-secret
      OIDC_CRYPTO_PASSPHRASE: random-crypto-passphrase
      OIDC_REQUIRE_CLAIM: resource_access.client-id.roles:mod-auth-openidc-test-access

  whoami:
    image: traefik/whoami
    networks:
      - app
    labels:
      traefik.enable: "true"
      traefik.tags: modauthopenidc-example
      traefik.docker.network: modauthopenidctest_app
      traefik.http.routers.httpd.rule: Host(`localhost`)
      traefik.http.routers.httpd.entrypoints: web
      traefik.http.middlewares.httpd_forwardauth.forwardauth.address: http://forwardauth:80/
      traefik.http.middlewares.httpd_forwardauth.forwardauth.authResponseHeaders: X-Forwarded-User
      traefik.http.routers.httpd.middlewares: httpd_forwardauth
```

In this example, Traefik sets the value of the `X-Forwarded-User` header returned from the forwardAuth container on the request, making it available to the app. See below for more information on returned headers.

# Available ENVs / Claims configuration

Note:
* for actual documentation on how to configure `mod_auth_openidc`, see https://github.com/zmartzone/mod_auth_openidc
* for actual documentation on how to configure Traefik and its ForwardAuth, see https://doc.traefik.io/traefik/middlewares/forwardauth/

For a full reference of available ENVs to configure `mod_auth_openidc`, check out [vhost.conf](./conf/vhost.conf).

Wherever possible, ENV names are identical to the `mod_auth_openidc` configuration directive, i.e. `OIDCProviderMetadataURL` -> `OIDC_PROVIDER_METADATA_URL`.

Of note are:
* `OIDC_PROVIDER_METADATA_URL`
* `OIDC_CLIENT_ID`
* `OIDC_CLIENT_SECRET`
* `OIDC_CRYPTO_PASSPHRASE`
* `OIDC_SCOPE` (default: `openid email`)
* `OIDC_REMOTE_USER_CLAIM` (default: `preferred_username`)
* `OIDC_REQUIRE_CLAIM` (default: empty)
* `OIDC_REQUIRE_CLAIM_1` through `OIDC_REQUIRE_CLAIM_10` (default: empty)

`OIDC_REQUIRE_CLAIM` ENVs are used to specify claims, see the quickstart example.

## Arbitrary additional configuration

A quick hassle-free way to add more specific configuration not available through the basic ENVs is through these two ENVs, the content of which is included directly in the Apache VHost and Location config blocks, respectively:
```yaml
  environment:
    OIDC_VHOST_EXTRA_CONFIG: |
      OIDCOAuthRemoteUserClaim Username
      OIDCSSLValidateServer
      ...
    OIDC_LOCATION_EXTRA_CONFIG: |
      Require claim ...
```
It is easily possible to completely break the configuration using this, especially with the Location block, since some of the "magic" is included in the Location block. Caution is advised.

Alternatively, additional configuration files can be included by mounting them inside the container:
* for the VHost configuration: `/conf/vhost.d/` and naming them `*.conf`
* for the Location configuration: `/conf/location.d/` and naming them `*.conf`

To **completely replace** the default configuration for advanced scenarios, the following files can be mounted. Mounting one or both of those files overwrites most of the default configuration, except the magic bits necessary for ForwardAuth functionality. Configuration through ENVs will not be available anymore, unless you make it so. You will be responsible for the full configuration.
* `/conf/vhost.conf`
* `/conf/location.conf`
**Note** that these files are subject to `envsubst` ENV substitution on container start.

# `mod_auth_openidc` headers

All headers set by `mod_auth_openidc` inside the forwardAuth container for the request and starting with `OIDC`, meaning to the best of my knowledge all headers set by the `mod_auth_openidc` module, are set as response headers on the forwardAuth response. This allows them to be sent to the app as request headers using, for example, Traefik's `authResponseHeaders` or `authResponseHeadersRegex` functionality.

This also (currently) includes the access token, which is set by `mod_auth_openidc` to the `OIDC-Access-Token` header, and the claims, set to the `OIDC-Claim-*` headers. Should `mod_auth_openidc` change its behavior related to these headers, this might change.

Security implications of sending headers with potentially sensitive data to the app should be considered.
