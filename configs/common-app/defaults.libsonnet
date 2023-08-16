local functions = import 'functions.libsonnet';
local templates = import 'templates.libsonnet';

{
  ports:: {
    /// Порт используемый в сервисах по умолчанию (http, 80)
    http: templates.port('http', 80),
  },

  /// Приоритет приложений, используемый по умолчанию
  priorityClassName:: 'applications',

  resources:: {
    /// Минимальные ресурсы/лимиты используемые по умолчанию
    requests: templates.resources(cpu=0.1, memory='0.5G'),
    limits: templates.resources(cpu=1, memory='1G'),
  },

  job:: {
    before:
      /// Ресурс Batch/Job, запускаемый перед релизом
      /// Определяется названием компонента
      function(component) templates.job(component, 'before', weight=1) {
        restartPolicy: 'Never',
        activeDeadlineSeconds: 14400,  // 4h
        ttlSecondsAfterFinished: 7200,  // 2h
        diagnostics+: {
          metrics: false,
          tracing: false,
        },
      },
    after:
      /// Ресурс Batch/Job, запускаемый после релиза
      /// Определяется названием компонента
      function(component) templates.job(component, 'after', weight=1) {
        restartPolicy: 'Never',
        activeDeadlineSeconds: 14400,  // 4h
        ttlSecondsAfterFinished: 7200,  // 2h
        diagnostics+: {
          metrics: false,
          tracing: false,
        },
      },
    regular:
      /// Ресурс Batch/Job, запускаемый, когда процесс релиза завершился
      /// Определяется названием компонента
      function(component) templates.job(component, '', weight=-1) {
        hook: null,
        restartPolicy: 'Never',
        activeDeadlineSeconds: 14400,  // 4h
        ttlSecondsAfterFinished: 7200,  // 2h
        diagnostics+: {
          metrics: false,
          tracing: false,
        },
      },
  },

  cronJob::
    /// Ресурс Batch/CronJob, с различными значениями параметров по умолчанию
    /// Определяется парой (компонент, расписание)
    function(component, schedule) templates.cronJob(component, schedule) {
      suspend: false,
      backoffLimit: 6,
      restartPolicy: 'Never',
      concurrencyPolicy: 'Forbid',
      failedJobsHistoryLimit: 3,
      successfulJobsHistoryLimit: 3,
      activeDeadlineSeconds: 14400,  // 4h
      startingDeadlineSeconds: 60,  // 1m
      ttlSecondsAfterFinished: 7200,  // 2h
      diagnostics+: {
        metrics: false,
        tracing: false,
      },
    },

  crons:: {
    /// Встроенные функции для генерации расписаний

    eachDay::
      /// Расписание на каждый Х день месяца
      /// Определяется указанием дня (0<=X<=31)
      function(day)
        if day < 0 || day > 31 then error 'Invalid value for days' else '0 0 */%s * *' % day,
    eachHour::
      /// Расписание на каждый Х час дня
      /// Определяется указанием часа (0<=X<=23)
      function(hour)
        if hour < 0 || hour > 23 then error 'Invalid value for hours' else '0 */%s * * *' % hour,
    eachMinute::
      /// Расписание на каждую Х минуту часа
      /// Определяется указанием минуты (0<=X<=59)
      function(minute)
        if minute < 0 || minute > 59 then error 'Invalid value for minutes' else '*/%s * * * *' % minute,
  },

  service:: {
    headless:
      /// Сервис типа Headless c портом по умолчанию
      /// Определяется названием компонента, на который будет направлен трафик
      function(component) templates.service(component) {
        type: 'ClusterIP',
        clusterIP: 'None',
        port: $.ports.http,
      },

    clusterIp:
      /// Сервис типа ClusterIp c портом по умолчанию
      /// Определяется названием компонента, на который будет направлен трафик
      function(component) templates.service(component) {
        type: 'ClusterIP',
        port: $.ports.http,
      },

    loadBalancer:
      /// Сервис типа LoadBalancer c портом по умолчанию
      /// Определяется названием компонента, на который будет направлен трафик
      function(component) templates.service(component) {
        type: 'LoadBalancer',
        port: $.ports.http,
      },
  },

  ingress::
    /// Ingress c настройками по умолчанию (выраженных в виде аннотаций)
    /// Определяется компонентом, который может быть опущен, если ресурс один на приложение
    /// Настройки: без автоматического сертификата, генерация DNS имени, энфорс HTTPS
    /// Также требуется сконфигурировать хост, http пути и TLS
    function(component=null) templates.ingress(component) {
      annotations+: {
        _combine(condition, value):: if condition then (
          if std.isArray(value) then value else [ value ]
        ) else [],

        certManager: {
          include: false,
          challenge: 'http01',
          issuer: 'letsencrypt',
          class: 'nginx',
        },
        externalDns: {
          ignore: false,
        },
        forceSSL: true,
        denyRobots: true,

        defaults:
          self._combine(self.certManager.include, functions.ingress.annotations.certManager(self.certManager.issuer, self.certManager.challenge)) +
          self._combine(
            self.certManager.include && self.certManager.challenge == 'http01',
            templates.annotation('acme.cert-manager.io/http01-ingress-class', self.certManager.class),
          ) +
          self._combine(self.externalDns.ignore, functions.ingress.annotations.externalDnsIgnore()) +
          self._combine(self.forceSSL, [
            functions.ingress.annotations.httpsOnly(),
            functions.ingress.annotations.sslRedirect(),
            functions.ingress.annotations.sslRedirectForce(),
          ]) +
          self._combine(self.denyRobots, functions.ingress.annotations.denyRobots()),
      },
    },

  ingressPrivate::
    function(component=null) self.ingress(component) {
      className: 'nginx-private',
      annotations+: {
        forceSSL: false,
      },
      tls: [],
    },

  probes:: {
    live:
      /// Liveness проба с настройками по умолчанию, по пути /health/live
      function(port) templates.probe('/health/live', port, threshold=3, delay=5, period=10, timeout=1),
    ready:
      /// Readiness проба с настройками по умолчанию, по пути /health/ready
      function(port) templates.probe('/health/ready', port, threshold=5, delay=10, period=30, timeout=1),
    startup:
      /// Startup проба с настройками по умолчанию, по пути /health/startup
      function(port) templates.probe('/health/startup', port, threshold=3, delay=5, period=5, timeout=1),
  },

  hpa:: {
    metrics:: {
      resource:: {
        averageUtilization::
          /// Метрика типа средняя утилизация (только для ресурсов)
          /// Определяется парой (ресурс, значение)
          function(resource, value)
            templates.hpa.metrics.resource(
              resource,
              target={ type: 'Utilization', value: value }
            ),
        averageValue::
          /// Метрика типа среднее значение
          /// Определяется парой (ресурс, значение)
          function(resource, value)
            templates.hpa.metrics.resource(
              resource,
              target={ type: 'AverageValue', value: value }
            ),
      },
      external:: {
        averageValue::
          /// Метрика типа среднее значение
          /// Определяется парой (метрика, значение)
          function(metric, value)
            templates.hpa.metrics.external(
              metric,
              target={ type: 'AverageValue', value: value },
            ),
        value::
          /// Метрика типа значение
          /// Определяется парой (метрика, значение)
          function(metric, value)
            templates.hpa.metrics.external(
              metric,
              target={ type: 'Value', value: value },
            ),
      },
      pods:: {
        averageValue::
          /// Метрика типа среднее значение по подам
          /// Определяется парой (метрика, значение)
          function(metric, value)
            templates.hpa.metrics.pods(
              metric,
              target={ type: 'AverageValue', value: value },
            ),
      },
      object:: {
        ingress:: {
          averageValue::
            /// Метрика типа среднее значение
            /// Определяется тройкой (метрика, ресурс Ingress, значение)
            function(metric, ingress, value)
              templates.hpa.metrics.object(
                metric,
                target={ type: 'AverageValue', value: value },
                describedObject={
                  apiVersion: 'networking.k8s.io/v1',
                  kind: 'Ingress',
                  name: ingress,
                }
              ),
          value::
            /// Метрика типа значение
            /// Определяется тройкой (метрика, ресурс Ingress, значение)
            function(metric, ingress, value)
              templates.hpa.metrics.object(
                metric,
                target={ type: 'Value', value: value },
                describedObject={
                  apiVersion: 'networking.k8s.io/v1',
                  kind: 'Ingress',
                  name: ingress,
                }
              ),
        },
      },
    },
    behavior:: {
      policies:: {
        percentageForSeconds:: function(percentage, seconds)
          templates.hpa.behavior.policy('Percent', percentage, seconds),
        podsForSeconds:: function(pods, seconds)
          templates.hpa.behavior.policy('Pods', pods, seconds),
      },

      scale:: {
        disabled::
          /// Отсутствие скалирования
          templates.hpa.behavior.scale(null, selectPolicy='Disabled', policies=[]),
        maxWithoutStabilization::
          /// Политика скалирования Max
          function(policies)
            templates.hpa.behavior.scale(stabilizationWindowSeconds=0, selectPolicy='Max', policies=policies),
        minWithStabilization::
          /// Политика скалирования Min
          function(stabilizationWindowSeconds, policies)
            templates.hpa.behavior.scale(stabilizationWindowSeconds, selectPolicy='Min', policies=policies),
      },
    },

    behaviors:: {
      default:: {
        scaleUp: $.hpa.behavior.scale.maxWithoutStabilization(
          policies=[
            $.hpa.behavior.policies.percentageForSeconds(100, 15),
          ]
        ),
        scaleDown: $.hpa.behavior.scale.minWithStabilization(
          stabilizationWindowSeconds=300,
          policies=[
            $.hpa.behavior.policies.percentageForSeconds(10, 60),
            $.hpa.behavior.policies.podsForSeconds(3, 60),
          ]
        ),
      },
    },
  },

  rbac:: {
    rule::
      /// Генерация RBAC правила
      /// Определяется тройкой (апи, ресурсы, действия)
      function(apis, resources, verbs) {
        apis: apis,
        resources: resources,
        verbs: verbs,
      },

    role::
      /// RBAC роль
      /// Может быть либо в рамках одного Namespace (namespaced = true, по умолчанию), либо в рамках кластера
      /// Также, необходимо задать правила
      function(namespaced=true, rules) templates.rbac.role(namespaced, rules) {
      },

    serviceAccount::
      /// ServiceAccount
      function() {
        create: true,
      },

    binding::
      /// Привязка (RoleBinding|ClusterRoleBinding)
      /// Опциональный параметр – replicateNamespaceSelector позволяет также выдавать права на сторонние неймспейсы
      function() {
        local this = self,

        replicateNamespaceSelector:: [],
        annotations: if this.replicateNamespaceSelector == [] then {} else {
          'replicator.v1.mittwald.de/replicate-to': std.join(',', this.replicateNamespaceSelector),
        },
      },
  },

  dns:: {
    aliases:: {
      frontDoors:: {
        prod::
          /// Ресурс externaldns.k8s.io/v1alpha1.endpoints типа Alias на we-afd-dodo
          function(domain) templates.dns.alias(domain, '/subscriptions/7f006c06-c0d2-4e5d-82d8-2e96d2ea6cd6/resourceGroups/we-rg/providers/Microsoft.Network/frontdoors/we-afd-dodo'),
      },
    },
  },
}
