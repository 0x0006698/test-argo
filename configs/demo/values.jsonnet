local defaults = import '../common-app/defaults.libsonnet';
local functions = import '../common-app/functions.libsonnet';
local templates = import '../common-app/templates.libsonnet';

local application = 'demo';

local secrets = function(environment, cluster, namespace) {
  components:: [application],
  items:: [],
  defaults:: {},
  overrides:: {},
  result: functions.objects.replaceIfExists($.defaults, $.overrides, cluster),
};

local environments = function(environment, cluster, namespace) {
  components:: [application],
  defaults:: [],

  overrides:: {},

  result: functions.objects.overrideIfExists($.defaults, $.overrides, cluster),
};

local clusterSettings = function(cluster) {
  defaults:: {
    deployments: {
      [application]: {
        replicas: 2,
        resources: defaults.resources {
          limits: templates.resources(cpu=1, memory='1G'),
        },
      },
    },
    imagePullSecrets: false,
  },

  overrides:: {
    dev: {
      deployments+: {
        [application]+: { replicas: 1 },
      },
    },
  },

  result: functions.objects.overrideIfExists($.defaults, $.overrides, cluster),
};

function(environment, cluster, namespace, image) {
  local settings = clusterSettings(cluster).result,

  local port = 5000,

  deployments: [
    templates.deployment(application) {
      priorityClassName: defaults.priorityClassName,
      args: [],
      resources: settings.deployments[super.component].resources,
      replicas: settings.deployments[super.component].replicas,
      ports: [
        templates.port('web', port),
      ],
      terminationGracePeriodSeconds: 60,
      dns: {
        policy: 'ClusterFirst',
      },

      probes: {},

      diagnostics: {
        metrics: false,
        tracing: false,
      },
    },
  ],
  services: [
    defaults.service.clusterIp(application) {
      port: templates.port('web', port),
      annotations+: [
        functions.service.annotations.generateIngress(),
      ],
    },
  ],
  environment: environments(environment, cluster, namespace).result,
  secrets: secrets(environment, cluster, namespace).result,
  image: image,
  imagePullSecrets: settings.imagePullSecrets,
}
