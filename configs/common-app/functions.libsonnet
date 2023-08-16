local templates = import 'templates.libsonnet';

{
  collections:: {
    zip::
      /// Функция позволяет склеить две последовательности в одну
      /// Определяется тройкой (левая последовательность, права последовательность, функция объединения)
      function(left, right, selector) std.mapWithIndex(function(index, item) selector(item, right[index]), left),

    toObject::
      /// Функция позволяет превратить массив в словарь по указанному ключу
      /// Определяется парой (массив, свойство)
      /// [{one: 'a'}, {one: 'b'}] => {a: {one: 'a'}, 'b': {one: 'b'}}
      function(items, property) {
        [item[property]]: item
        for item in items
      },

    overrideProperty::
      /// Функция позволяет переопределить свойство у элементов массива, вызывая на каждый элемент функцию override
      function(override, array) std.map(function(item) {
        [property]: item[property]
        for property in std.objectFields(item)
      } + override(item), array),
  },

  objects:: {
    overrideIfExists::
      /// Функция позволяет переопределить значения объекта default, если в overrideObject существует ключ overrideObjectKey
      /// В противном случае будет использован default
      /// ({some: val}, {test: {some: val1, other: val2}}, test) => {some: val1, other: val2}
      function(default, overrideObject, overrideObjectKey)
        if std.objectHas(overrideObject, overrideObjectKey) then default + overrideObject[overrideObjectKey] else default,

    replaceIfExists::
      /// Функция использует overrideObject если в нем существует ключ overrideObjectKey
      /// В противном случае будет использован default
      /// ({some: val, test: val3}, {test: {some: val1, other: val2}}, test) => {some: val1, other: val2}
      function(default, overrideObject, overrideObjectKey)
        if std.objectHas(overrideObject, overrideObjectKey) then overrideObject[overrideObjectKey] else default,

    overrideProperty::
      /// Функция позволяет переопределить свойства у объекта, вызывая на каждое свойство функцию override
      function(default, override) {
        [property]: default[property] + override(property)
        for property in std.objectFields(default)
      },
  },

  arrays:: {
    overrideIfExists::
      function(default, overrideObject, filterKey, overrideObjectKey)
        if std.objectHas(overrideObject, overrideObjectKey)
        then
          local overrideArray = std.set(overrideObject[overrideObjectKey], function(x) x[filterKey],);
          std.filter(function(x) !std.setMember(x, overrideArray, function(x) x[filterKey],), default) + overrideArray
        else default,
  },

  namespace:: {
    prefix: function(namespace) {
      local parts = std.split(namespace, '-'),

      result: if std.length(parts) == 1 then parts[0] else parts[1],
    }.result,
  },

  keyvault:: {
    name:: {
      app:
        /// Функция генерирует имя KeyVault по шаблону:
        /// Кластер-kv-приложение-dodo
        /// Определяется парой (кластер, приложение)
        function(cluster, application) '%(cluster)s-kv-%(app)s-dodo' % {
          cluster: cluster,
          app: std.substr(application, 0, 13),
        },
      stand:
        /// Функция генерирует имя KeyVault по шаблону:
        /// Кластер-Стенд-keyvault-dodo
        /// Определяется парой (кластер, неймспейс)
        /// stage - уникальный стенд, готовится к удалению
        function(cluster, namespace) if namespace == 'stage' then '%(cluster)s-%(namespace)s-keyvault-dodo' % {
          cluster: cluster,
          namespace: $.namespace.prefix(namespace),
        } else '%(cluster)s-%(namespace)s-kv-dodo' % {
          cluster: cluster,
          namespace: $.namespace.prefix(namespace),
        },
      infra:
        /// Функция генерирует имя KeyVault по шаблону:
        /// Кластер-keyvault-dodo
        /// Определяется параметром кластер
        function(cluster) '%(cluster)s-keyvault-dodo' % {
          cluster: cluster,
        },
    },

    secrets:: {
      app:
        /// Функция переопределяет названия секретов, добавляя префикс к каждому секрету в виде названия неймспейса
        /// Пример вызова:
        /// (drinkit, [{ variable: env-var, name: secret-name, components: [] }]) => [ variable: env-var, k8s_secret: secret-name, kv_secret: drinkit-secret-name, components: [] ]
        function(namespace, secrets) $.collections.overrideProperty(function(item) {
          k8s_secret: item.name,
          kv_secret: '%(namespace)s-%(name)s' % { namespace: namespace, name: item.name },
        }, secrets),

      stand:
        /// Функция переопределяет названия секретов, добавляя префикс к каждому секрету в виде названия приложения
        /// Пример вызова:
        /// (tracker, [{ variable: env-var, name: secret-name, components: [] }]) => [ variable: env-var, k8s_secret: secret-name, kv_secret: tracker-secret-name, components: [] ]
        function(application, secrets) $.collections.overrideProperty(function(item) {
          k8s_secret: item.name,
          kv_secret: '%(app)s-%(name)s' % { app: application, name: item.name },
        }, secrets),
    },
  },

  environment:: {
    defaults::
      /// Функция генерирует переменные окружения по умолчанию
      /// ENVIRONMENT (ASPNETCORE_ENVIRONMENT), CLUSTER, NAMESPACE
      function(environment, cluster, namespace, components) [
        templates.environment('ASPNETCORE_ENVIRONMENT', environment, components),
        templates.environment('ENVIRONMENT', environment, components),
        templates.environment('CLUSTER', cluster, components),
        templates.environment('NAMESPACE', namespace, components),
      ],
  },

  volumes:: {
    emptyDir::
      /// Функция генерирует спецификацию для вольюма типа emptyDir с ограничением по размеру, по пути
      /// Определяется тройкой (название, путь, размер)
      function(name, mountPath, size, medium='""') {
        name: name,
        type: 'emptyDir',
        mountPath: mountPath,
        size: size,
        medium: medium,
      },
  },

  service:: {
    annotations:: {
      loadBalancerToIngressIgnore::
        /// Функция генерирует аннотацию, заставляющую поменять сервис типа LoadBalancer на сервис типа ClusterIp + Private Ingress
        function()
          templates.annotation('policies.dodois.io/replace-loadbalancer-svc-with-ingress-ignore', 'true'),

      generateIngress::
        /// Функция генерирует аннотацию, заставляющую сгенерировать Private Ingress для данного сервиса типа ClusterIp
        function()
          templates.annotation('policies.dodois.io/generate-ingress', 'true'),
    },
  },

  ingress:: {
    annotations:: {
      local this = self,

      configurationSnippet::
        /// Функция генерирует аннотацию типа configuration-snippet для ресурса Ingress
        function(value) templates.annotation(
          'nginx.ingress.kubernetes.io/configuration-snippet',
          |||
            %s
          ||| % value
        ),
      serverSnippet::
        /// Функция генерирует аннотацию типа server-snippet для ресурса Ingress
        function(value) templates.annotation(
          'nginx.ingress.kubernetes.io/server-snippet',
          |||
            %s
          ||| % value
        ),
      proxyRealIp::
        /// Функция добавляет поддержку X-Forwarded-For для ресурса Ingress
        function() this.serverSnippet('real_ip_header X-Forwarded-For;\nreal_ip_recursive on;'),

      denyLocations::
        /// Функция добавляет запрет на указанные пути для ресурса Ingress
        function(locations)
          this.configurationSnippet(
            std.join(
              '\n',
              [
                'location ~* ^%s {\n  deny all;\n  return 404;\n}' % location
                for location in locations
              ]
            )
          ),

      denyLocationsServer::
        /// Функция добавляет запрет на указанные пути для ресурса Ingress
        function(locations)
          this.serverSnippet(
            std.join(
              '\n',
              [
                'location ~* ^%s {\n  deny all;\n  return 404;\n}' % location
                for location in locations
              ]
            )
          ),

      customHttpErrors::
        /// Функция добавляет поддержку выделенных кодов ошибок для ресурса Ingress
        function(errors) templates.annotation('nginx.ingress.kubernetes.io/custom-http-errors', std.join(',', [ std.toString(err) for err in errors ])),

      redirectWww::
        /// Функция добавляет поддержку редиректа с WWW домена для ресурса Ingress
        function() templates.annotation('nginx.ingress.kubernetes.io/from-to-www-redirect', 'true'),

      readTimeout::
        /// Функция добавляет поддержку proxy read timeout для ресурса Ingress
        function(seconds) templates.annotation('nginx.ingress.kubernetes.io/proxy-read-timeout', '%s' % seconds),

      sendTimeout::
        /// Функция добавляет поддержку proxy send timeout для ресурса Ingress
        function(seconds) templates.annotation('nginx.ingress.kubernetes.io/proxy-send-timeout', '%s' % seconds),

      grpc::
        /// Функция добавляет необходимые аннотации для поддержки GRPC для ресурса Ingress
        function(application) [
          templates.annotation('nginx.ingress.kubernetes.io/backend-protocol', 'GRPC'),
          templates.annotation('nginx.ingress.kubernetes.io/grpc-backend', 'true'),
          templates.annotation('nginx.org/grpc-services', application),
        ],

      certManager::
        /// Функция генерирует аннотацию к CertManager, позволяющую указать необходимый центр выпуска сертификатов
        function(issuer, challenge) templates.annotation('cert-manager.io/cluster-issuer', '%s-prod-%s' % [ issuer, challenge ]),

      externalDnsIgnore::
        /// Функция генерирует аннотацию к ExternalDNS, позволяющую НЕ создавать доменное имя для ресурса Ingress
        function() templates.annotation('external-dns.kubernetes.io/ignore', 'true'),

      httpsOnly::
        /// Функция генерирует аннотацию запрещающую использование HTTP для ресурса Ingress
        function() templates.annotation('kubernetes.io/ingress.allow-http', 'false'),

      sslRedirect::
        /// Функция генерирует аннотацию устанавливающую SSL редирект для ресурса Ingress
        function() templates.annotation('nginx.ingress.kubernetes.io/ssl-redirect', 'true'),

      sslRedirectForce::
        /// Функция генерирует аннотацию устанавливающую SSL редирект для ресурса Ingress
        function() templates.annotation('nginx.ingress.kubernetes.io/force-ssl-redirect', 'true'),

      denyRobots::
        /// Функция генерирует аннотацию, добавляющую поддержку robots.txt для ресурса Ingress
        /// Данный robots.txt отключает индексацию для ресурса Ingress
        function() this.serverSnippet('location = /robots.txt { return 200 "User-agent: *\\nDisallow: /\\n"; }'),
    },

    tlsSecret::
      /// Функция генерирует название общего TLS секрета по кластеру
      function(environment, cluster, app) {
        local suffixes = {
          dev: 'dodois-dev',
          private: 'private-dodois-dev',
          ld: 'ld-dodois-dev',
          we: 'dodois-io',
          ru: 'dodois-ru',
          ruld: 'dodopizza-tech',
        },

        result: 'tls-wildcard-%(suffix)s' % {
          app: app,
          suffix: suffixes[cluster],
        },
      }.result,

    tlsSecretCustom::
      /// Функция генерирует название выделенного TLS секрета по кластеру, приложению
      /// Выделенный секрет требуется для отдельного доменного имени
      function(app, domain)
        'tls-%s-%s' % [ app, std.strReplace(domain, '.', '-') ],

    hostname::
      /// Функция генерирует hostname для приложения, по кластеру
      function(environment, cluster, namespace, app) {
        local domains = {
          dev: 'dodois.dev',
          private: 'private.dodois.dev',
          pay: 'pay.dodois.io',
          ld: 'ld.dodois.dev',
          we: 'dodois.io',
          ru: 'dodois.ru',
          ruld: 'dodopizza.tech',
        },
        local prefixes = {
        },
        local namespaces = {
          default: '',
        },

        result: '%(app)s%(namespace)s%(prefix)s.%(domain)s' % {
          app: app,
          domain: domains[cluster],
          prefix: $.objects.overrideIfExists('', prefixes, cluster),
          namespace: $.objects.replaceIfExists('.%s' % namespace, namespaces, namespace),
        },
      }.result,

    privateHostname::
      /// Функция генерирует hostname приватного ингресса для приложения
      function(environment, cluster, namespace, app) {
        local domains = {
          dev: 'dodois.dev',
          private: 'private.dodois.dev',
          pay: 'pay.dodois.io',
          ld: 'ld.dodois.dev',
          we: 'dodois.io',
          ru: 'dodois.ru',
          ruld: 'dodopizza.tech',
        },

        result: '%(app)s.%(namespace)s.%(cluster)s.%(domain)s' % {
          app: app,
          domain: domains[cluster],
          cluster: cluster,
          namespace: namespace,
        },
      }.result,
  },

  profiling:: {
    default:: function(namespace) {
      pyroscopeScrapeMemory: false,
      pyroscopeScrapeCpu: false,
      sampleRate: 100,
      tags: {
        namespace: namespace,
      },
    },
  },
}
