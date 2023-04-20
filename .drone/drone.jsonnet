// Run "make drone" to regenerate drone.yml from this file
local archs = ['arm64', 'amd64'];

local onPRs = {
  event: ['pull_request'],
};

local onTag = {
  event: ['tag'],
};

local onMain = {
  event: ['push'],
};

local onTagOrMain = {
  event: ['push', 'tag'],
};

local pipeline(name) = {
  kind: 'pipeline',
  name: name,
  steps: [],
  trigger: {
    // Only trigger pipelines for PRs, tags (v*), or pushes to "main".
    ref: ['refs/heads/main', 'refs/tags/v*'],
  },
};

local secret(name, vault_path, vault_key) = {
  kind: 'secret',
  name: name,
  get: {
    path: vault_path,
    name: vault_key,
  },
};
local docker_username_secret = secret('docker_username', 'infra/data/ci/docker_hub', 'username');
local docker_password_secret = secret('docker_password', 'infra/data/ci/docker_hub', 'password');

local buildx(app) = {
  name: '%s-docker-buildx' % app,
  image: 'thegeeklab/drone-docker-buildx:23',
  privileged: false,
  settings: {
    auto_tag: true,
    repo: 'grafana/%s' % app,
    dockerfile: 'Dockerfile',
    platforms: ['linux/%s' % arch for arch in archs],
    username: { from_secret: docker_username_secret.name },
    password: { from_secret: docker_password_secret.name },
    dry_run: false,
  },
};

local autoinstrument() = pipeline('ebpf-autoinstrument') {
  steps+: [
    buildx('ebpf-autoinstrument-dryrun') {
      when: onPRs,
      settings+: {
        dry_run: true,
      },
    },
  ] + [
    buildx('ebpf-autoinstrument') {
      when: onTagOrMain,
    },
  ],
};

// TODO: don't create images if unit tests nor integration tests pass
[
  autoinstrument(),
] + [
  docker_username_secret,
  docker_password_secret,
]