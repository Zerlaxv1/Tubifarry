# syntax=docker/dockerfile:1

# Builds the Lidarr song-mode fork with the Tubifarry plugin already installed.
#
# The host and the plugin are compiled in separate steps on purpose: AssemblyVersion is
# pinned in the fork (upstream wildcards it off the build clock), so a plugin built here
# loads into a host built there. That was not true before and produced images where Lidarr
# started fine and the plugin silently never loaded.

ARG DOTNET_VERSION=8.0
ARG NODE_MAJOR=20
ARG RUNTIME=linux-x64
ARG FRAMEWORK=net8.0

# ---------------------------------------------------------------- build

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build

ARG NODE_MAJOR
ARG RUNTIME
ARG FRAMEWORK

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g yarn \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Host: self-contained, so the runtime image needs native dependencies only.
# build.sh runs yarn install itself as part of --frontend.
WORKDIR /src/Submodules/Lidarr
RUN ./build.sh --backend --frontend --packages --runtime "${RUNTIME}" --framework "${FRAMEWORK}"

# Plugin: built against that same pinned assembly version.
WORKDIR /src
RUN dotnet build Tubifarry/Tubifarry.csproj -c Release -p:RunAnalyzers=false

# Fail loudly here rather than shipping an image whose plugin cannot load.
RUN test -x "/src/Submodules/Lidarr/_artifacts/${RUNTIME}/${FRAMEWORK}/Lidarr/Lidarr" \
 && test -f /src/_plugins/Tubifarry/Lidarr.Plugin.Tubifarry.dll

# ---------------------------------------------------------------- runtime

FROM mcr.microsoft.com/dotnet/runtime-deps:${DOTNET_VERSION} AS runtime

ARG RUNTIME
ARG FRAMEWORK

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates ffmpeg sqlite3 tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/Submodules/Lidarr/_artifacts/${RUNTIME}/${FRAMEWORK}/Lidarr /app

# Staged, not installed: plugins live in the data directory, which is a volume and only
# exists at run time. The entrypoint syncs it on every start so the plugin always matches
# the image rather than whatever an older container left behind.
COPY --from=build /src/_plugins/Tubifarry /opt/tubifarry

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /app/Lidarr

ENV XDG_CONFIG_HOME=/config \
    TUBIFARRY_OWNER=Zerlaxv1 \
    COMPlus_EnableDiagnostics=0

VOLUME /config /music /downloads
EXPOSE 8686

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
