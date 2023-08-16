{
  shared:: {
    annotation:: {
      /// Поля необходимые для аннотации в метаданных ресурса (resource annotation)
      name: error 'annotation.name must be defined',
      value: error 'annotation.value must be defined',
    },

    port:: {
      /// Поля необходимые для задания порта (deployment port, svc port, etc.)
      name: error 'port.name must be defined',
      port: error 'port.port must be defined',
      protocol: error 'port.protocol must be defined',
      targetPort: error 'port.targetPort must be defined',
    },

    probe:: {
      /// Поля необходимые для задания пробы (live, ready, startup probe)
      httpGet: {
        path: error 'probe.httpGet.path must be defined',
        port: error 'probe.httpGet.port must be defined',
      },
      failureThreshold: error 'probe.failureThreshold must be defined',
      periodSeconds: error 'probe.periodSeconds must be defined',
      initialDelaySeconds: error 'probe.initialDelaySeconds must be defined',
    },

    resources:: {
      /// Поля необходимые для задания ресурсов (requests & limits)
      cpu: error 'resources.cpu must be defined',
      memory: error 'resources.memory must be defined',
    },
  },

  deployment:: {
    /// Основные поля для ресурса Apps/Deployment
    component: error 'deployment.component must be defined',
    annotations: [],
    command: [],
    args: [],
    workingDir: error 'deployment.workingDir must be defined',
    resources: {
      limits: $.shared.resources,
      requests: $.shared.resources,
    },
    ports: [],
    diagnostics: {
      tracing: error 'deployment.diagnostics.tracing must be defined',
      metrics: error 'deployment.diagnostics.metrics must be defined',
      profiling: {
        enabled: error 'deployment.diagnostics.profiling.enabled must be defined',
        configuration: error 'deployment.diagnostics.profiling.configuration must be defined',
      },
    },
    probes: {
      ready: $.shared.probe,
      live: $.shared.probe,
    },
  },

  service:: {
    /// Основные поля для ресурса Service
    annotations: error 'service.annotations must be defined',
    component: error 'service.component must be defined',
    type: error 'service.type must be defined',
    port: $.shared.port,
    extraPorts: error 'service.extraPorts must be defined',
    clusterIP: ''
  },

  host:: {
    /// Поля необходимые для задания адреса (host) у ресурса Ingress
    hostname: error 'host.hostname must be defined',
    paths: error 'host.paths must be defined',
  },

  hostPath:: {
    /// Поля необходимые для задания URL сегмента (paths) у ресурса Ingress
    path: error 'hostPath.path must be defined',
    component: error 'hostPath.component must be defined',
  },

  hostPathToService:: {
    /// Поля необходимые для задания URL сегмента (paths) у ресурса Ingress
    path: error 'hostPathToService.path must be defined',
    service: error 'hostPathToService.service must be defined',
    portName: error 'hostPathToService.portName must be defined',
  },

  tls:: {
    /// Поля необходимые для задания TLS конфигурации хоста у ресурса Ingress
    hostname: error 'tls.hostname must be defined',
    secret: error 'tls.secret must be defined',
  },

  ingress:: {
    /// Основные поля для ресурса Networking/Ingress
    annotations: {},
    hosts: error 'ingress.hosts must be defined',
    tls: error 'ingress.tls must be defined',
  },

  job:: {
    /// Основные поля для ресурса Batch/Job
    component: error 'job.component must be defined',
    hook: {
      type: error 'job.hook.type must be defined',
      weight: error 'job.hook.weight must be defined',
    },
    command: [],
    args: [],
    diagnostics: {
      tracing: error 'job.diagnostics.tracing must be defined',
      metrics: error 'job.diagnostics.metrics must be defined',
    },
    workingDir: error 'job.workingDir must be defined',
    resources: {
      limits: $.shared.resources,
      requests: $.shared.resources,
    },
    activeDeadlineSeconds: error 'job.activeDeadlineSeconds must be defined',
    restartPolicy: error 'job.restartPolicy must be defined',
    ttlSecondsAfterFinished: error 'job.ttlSecondsAfterFinished must be defined',
  },

  cronJob:: {
    /// Основные поля для ресурса Batch/CronJob
    component: error 'cronJob.component must be defined',
    command: [],
    args: [],
    diagnostics: {
      tracing: error 'cronJob.diagnostics.tracing must be defined',
      metrics: error 'cronJob.diagnostics.metrics must be defined',
    },
    workingDir: error 'cronJob.workingDir must be defined',
    resources: {
      limits: $.shared.resources,
      requests: $.shared.resources,
    },
    activeDeadlineSeconds: error 'cronJob.activeDeadlineSeconds must be defined',
    restartPolicy: error 'cronJob.restartPolicy must be defined',
    concurrencyPolicy: error 'cronJob.concurrencyPolicy must be defined',
    failedJobsHistoryLimit: error 'cronJob.failedJobsHistoryLimit must be defined',
    successfulJobsHistoryLimit: error 'cronJob.successfulJobsHistoryLimit must be defined',
    schedule: error 'cronJob.schedule must be defined',
    startingDeadlineSeconds: error 'cronJob.startingDeadlineSeconds must be defined',
    ttlSecondsAfterFinished: error 'cronjob.ttlSecondsAfterFinished must be defined',
  },

  secret:: {
    /// Основные поля для ресурса AKVS (AzureKeyVaultSecret)
    components: error 'secret.components must be defined',
    variable: error 'secret.variable must be defined',
    k8s_secret: error 'secret.k8s_secret must be defined',
    kv_secret: error 'secret.kv_secret must be defined',
  },

  externalSecrets:: {
    /// Основные поля для ресурса es (ExternalSecret)
    lockbox:: {
      componentSecret:: {
        /// Основные поля для ресурса es, хранящего секреты конкретного компонента (ExternalSecret)
        provider: error 'externalSecret.componentSecret.provider must be defined',
        component: error 'externalSecret.componentSecret.component must be defined',
        secretId: error 'externalSecret.componentSecret.secretId must be defined',
        items: error 'externalSecret.componentSecret.items must be defined',
      },

      item:: {
        variable: error 'externalSecret.componentSecret.item.variable must be defined',
        property: error 'externalSecret.componentSecret.item.property must be defined',
      },
    },
  },

  environment:: {
    /// Основные поля для переменной окружения, предназначенной для компонентов
    name: error 'environment.name must be defined',
    value: error 'environment.value must be defined',
    components: error 'environment.components must be defined',
  },

  hpa:: {
    /// Основные поля для ресурса autoscaling/HorizontalPodAutoscaler
    minReplicas: error 'hpa.minReplicas must be defined',
    maxReplicas: error 'hpa.maxReplicas must be defined',
    metrics: error 'hpa.metrics must be defined',
  },

  rbac:: {
    role:: {
      /// Основные поля для ресурса типа Role (ClusterRole)
      namespaced: error 'role.namespased must be defined',
      rules: error 'role.rules must be defined',
    },
  },
}
