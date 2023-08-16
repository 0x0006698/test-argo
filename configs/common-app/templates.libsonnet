local schemas = import 'schemas.libsonnet';

{
  annotation:: function(name, value) schemas.shared.annotation {
    /// Аннотация в метаданных. Является парой типа ключ-значение
    name: name,
    value: value,
  },

  environment:: function(name, value, components) schemas.environment {
    /// Переменная окружения.
    /// Определяется как тройка (название, значение, список компонентов к которым применяется)
    name: name,
    value: value,
    components: components,
  },

  environmentRef:: function(name, reference, components) schemas.environment {
    /// Переменная окружения, которая ссылается на другую переменную окружения
    /// Определяется как тройка (название, название другой переменной, список компонентов к которым применяется)
    name: name,
    value: '$(%s)' % reference,
    components: components,
  },

  secret:: function(variable, name, components) schemas.secret {
    /// Переменная окружения в виде секрета
    /// Определяется как четверка (название, название секрета в kv, название секрета в k8s, список компонентов к которым применяется)
    variable: variable,
    k8s_secret: name,
    kv_secret: name,
    components: components,
  },

  secretTemplate:: function(variable, name, components) {
    /// Шаблон переменной окружения в виде секрета
    /// Определяется как тройка (название, название секрета, список компонентов к которым применяется)
    /// Шаблон используется для генерации секретов (через функцию secret) путем изменения поля name в зависимости от типа приложения/кластера
    variable: variable,
    name: name,
    components: components,
  },

  secretMountTemplate:: function(dataKey, name, mountPath, components) {
    /// Шаблон переменной окружения в виде файлового маунта
    /// Определяется как тройка (поле, название секрета, путь в файловой системе, список компонентов к которым применяется)
    /// Шаблон используется для генерации секретов путем изменения поля name в зависимости от типа приложения/кластера
    variable: dataKey,
    name: name,
    mountPath: mountPath,
    components: components,
  },

  externalSecrets:: {
    lockbox:: {
      componentSecret:: function(component, secretId, items) schemas.externalSecrets.lockbox.componentSecret {
        provider: 'lockbox',
        component: component,
        secretId: secretId,
        items: items,
        mount: std.foldl(function(acc, x) acc || std.objectHas(x, 'mountPath'), self.items, false),
      },

      item:: function(namespace, variable, property) schemas.externalSecrets.lockbox.item {
        variable: variable,
        property: '%s-%s' % [ namespace, property ],
      },

      itemMount:: function(namespace, variable, property, mountPath) schemas.externalSecrets.lockbox.item {
        variable: variable,
        property: '%s-%s' % [ namespace, property ],
        mountPath: mountPath,
      },
    },
  },

  host:: function(hostname, paths) schemas.host {
    /// Hostname для ресурса Networking/Ingress
    /// Определяется как пара (хост, список ресурсов hostPath)
    hostname: hostname,
    paths: paths,
  },

  hostPath:: function(path, component) schemas.hostPath {
    /// HostPath для ресурса Networking/Ingress
    /// Определяется как пара (path, компонент на который должен направляться трафик)
    path: path,
    component: component,
  },

  hostPathToService:: function(path, service, portName='http') schemas.hostPathToService {
    /// HostPath для ресурса Networking/Ingress
    /// Определяется как набор значений (path, сторонний сервис на который должен направляться трафик, название порта у сервиса)
    path: path,
    service: service,
    portName: portName,
  },

  tls:: function(hostname, secret) schemas.tls {
    /// TLS конфигурация для хоста ресурса Networking/Ingress
    /// Определяется как пара (хост, секрет в котором лежит сертификат)
    hostname: hostname,
    secret: secret,
  },

  port:: function(name, value, protocol='TCP', target=value) schemas.shared.port {
    /// Порт для ресурса Service|Apps/Deployment|etc
    /// Определяется как кортеж (название, порт, протокол – по умолчанию TCP, порт контейнера - по умолчанию тот же порт)
    name: name,
    port: value,
    protocol: protocol,
    targetPort: target,
  },

  probe:: function(path, port, threshold, delay, period, timeout) schemas.shared.probe {
    /// HTTP проба (live, ready, startup) для ресурсов Apps/Deployment/etc
    /// Определяется как кортеж (http путь, порт, предел ошибок, начальная задержка, период, таймаут)
    httpGet: {
      path: path,
      port: port,
    },
    failureThreshold: threshold,
    periodSeconds: period,
    initialDelaySeconds: delay,
    timeoutSeconds: timeout,
  },

  resources:: function(cpu, memory) schemas.shared.resources {
    /// Ресурсы
    /// Определяется как пара (процессор, память)
    cpu: cpu,
    memory: memory,
  },

  strategy:: {
    /// Стратегии обновления Apps/Deployment

    recreate:: function() {
      /// Стратегия говорит о том, что будут сначала удалены а потом пересозданы все поды Deployment
      type: 'Recreate',
    },

    rollingUpdate:: function(surge='25%', unavailable='25%') {
      /// Стратегия говорит о том, что будет выполнено плавное обновление со старой версии на новую
      /// Определяется как пара (surge, unavailable)
      /// Значения говорят о том,
      ///  * сколько новых подов будет создано перед обновлением (surge)
      ///  * сколько старых подов будет удалено во время обновления (unavailable)
      type: 'RollingUpdate',
      rollingUpdate: {
        maxSurge: surge,
        maxUnavailable: unavailable,
      },
    },
  },

  deployment:: function(component) schemas.deployment {
    /// Шаблон для ресурса Apps/Deployment
    /// Определяется названием компонента, которому соответствует
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    component: component,
    diagnostics+: {
      tracing: true,
      metrics: true,
      profiling+: {
        enabled: false,
        configuration: {},
      },
    },
    dns: {
      policy: 'ClusterFirst',
      config: {},
      hostAliases: [],
    },
    maxUnavailable: '25%',
    terminationGracePeriodSeconds: 30,
    replicas: 0,
    workingDir: null,
  },

  secureDeployment:: function(component) $.deployment(component) {
    /// Шаблон для ресурса Apps/Deployment с включенным readOnlyRootFilesystem
    /// Определяется названием компонента, которому соответствует
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    securityContext: {
      readOnlyRootFilesystem: true
    }
  },

  service:: function(component) schemas.service {
    /// Шаблон для ресурса Service
    /// Определяется названием компонента, которому соответствует
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    annotations: [],
    component: component,
    extraPorts: [],
    slug: '',
  },

  job:: function(component, type, weight) schemas.job {
    /// Шаблон для ресурса Batch/Job выполняющейся перед/после релиза
    /// Определяется тройкой (компонент, тип, вес)
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    component: component,
    hook: {
      type: type,
      weight: weight,
    },
    workingDir: null,
  },

  cronJob:: function(component, schedule) schemas.cronJob {
    /// Шаблон для ресурса Batch/CronJob
    /// Определяется парой (компонент, расписание)
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    component: component,
    schedule: schedule,
    workingDir: null,
  },

  ingress:: function(component=null) schemas.ingress {
    /// Шаблон для ресурса Networking/Ingress
    /// Определяется названием компонента, которому соответствует
    /// Компонент может отсутствовать, если ресурс один на приложение
    /// Содержит набор базовых полей со значениями по умолчанию
    /// Требует определения дополнительных полей
    component: component,
    className: 'nginx',
    annotations: {
      additional: [],

      // todo: should be removed from here after all dependent apps migrated
      externalDnsSkip: false,
    },
  },

  grafanaAnnotation:: function(dashboardId, panelIds) {
    /// Аннотации к панели для Grafana
    /// Определяется парой (id дашборда, id панелей)
    dashboardId: dashboardId,
    panelIds: panelIds,
  },

  rbac:: {
    role:: function(namespaced, rules) schemas.rbac.role {
      /// Шаблон для ресурса типа Role/ClusterRole
      /// Определяется парой (namespaced который говорит о необходимости создать кластерную роль, набором правил)
      namespaced: namespaced,
      rules: rules,
    },
  },

  hpa:: {
    new:: function(minReplicas, maxReplicas) schemas.hpa {
      /// Шаблон для ресурса Autoscaling/HorizontalPodAutoscaler
      minReplicas: minReplicas,
      maxReplicas: maxReplicas,
    },

    metrics:: {
      new:: function(name, labels={}) {
        /// Шаблон для определения метрики
        /// Определяется парой (название, список лейблов)
        name: name,
        labels: labels,
      },

      resource:: function(name, target) {
        /// Метрика типа Resource
        /// Определяется парой (название, значение параметра)
        type: 'Resource',
        resource: name,
        target: target,
      },

      pods:: function(metric, target) {
        /// Метрика типа Pods
        /// Определяется парой (метрика, значение параметра)
        type: 'Pods',
        metric: metric,
        target: target,
      },

      external:: function(metric, target) {
        /// Метрика типа External
        /// Определяется парой (метрика, значение параметра)
        type: 'External',
        metric: metric,
        target: target,
      },

      object:: function(metric, target, describedObject) {
        /// Метрика типа Object
        /// Определяется тройкой (метрика, значение параметра, ресурс у которого забирать значение метрики)
        type: 'Object',
        metric: metric,
        target: target,
        describedObject: describedObject,
      },
    },

    behavior:: {
      scale:: function(stabilizationWindowSeconds, selectPolicy, policies) {
        stabilizationWindowSeconds: stabilizationWindowSeconds,
        selectPolicy: selectPolicy,
        policies: policies,
      },

      policy:: function(type, value, period) {
        type: type,
        value: value,
        periodSeconds: period,
      },
    },
  },

  dns:: {
    endpoint:: function(domain, type, ttl) {
      /// Шаблон для генерации ресурса externaldns.k8s.io/v1alpha1.endpoints
      /// Определяется тройкой (домен, тип, ttl)
      dnsName: domain,
      recordType: type,
      recordTTL: ttl,
    },

    cname:: function(domain, alias) self.endpoint(domain, type='CNAME', ttl=300) {
      /// Шаблон для генерации ресурса externaldns.k8s.io/v1alpha1.endpoints
      /// Определяется тройкой (домен, тип, ttl)
      targets: [ alias ],
    },

    alias:: function(domain, resource) self.endpoint(domain, type='A', ttl=300) {
      /// Ресурс externaldns.k8s.io/v1alpha1.endpoints типа Alias
      /// Определяется как пара (домен, ресурс в Azure)
      target: [ resource ],
      providerSpecific: [
        { name: 'Type', value: 'Alias' },
      ],
    },

    a:: function(domain, ips) self.endpoint(domain, type='A', tll=300) {
      /// Ресурс externaldns.k8s.io/v1alpha1.endpoints типа A
      /// Определяется как пара (домен, адрес/или список адресов)
      targets: if std.isArray(ips) then ips else [ ips ],
    },
  },
}
