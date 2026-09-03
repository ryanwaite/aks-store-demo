extension radius

param aiDeploymentName string

param aiEndpoint string

param aiImageDeploymentName string

param aiImageEndpoint string

@secure()
param aiKey string

param environment string

@secure()
param rabbitPassword string

@secure()
param registryPassword string

@secure()
param registryUsername string

resource aksStoreDemoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'aks-store-demo'
  properties: {
    environment: environment
  }
}

resource mongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongo'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/makeline-service/mongodb.go#L132'
    database: 'orderdb'
  }
}

resource rabbitMQ 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/order-service/plugins/messagequeue.js#L26'
    password: rabbitPassword
    queue: 'orders'
    username: 'username'
  }
}

resource aiServiceCredentials 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'ai-service-credentials'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/ai-service/routers/description_generator.py#L137'
    data: {
      AZURE_OPENAI_API_KEY: {
        value: aiKey
      }
    }
    kind: 'generic'
  }
}

resource rabbitCredentials 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'rabbit-client-credentials'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/order-service/plugins/messagequeue.js#L29'
    data: {
      password: {
        value: rabbitPassword
      }
    }
    kind: 'generic'
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/.github/workflows/release-container-images.yaml#L53'
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
    kind: 'basicAuthentication'
  }
}

resource storeAdminNginxConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-admin-nginx-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-admin/nginx.conf#L1'
    data: {
      'default.conf': {
        #disable-next-line use-secure-value-for-secure-inputs
        value: replace(replace(replace('''
upstream makeline_service {
    server __MAKELINE_HOST__:3001;
}

upstream order_service {
    server __ORDER_HOST__:3000;
}

upstream product_service {
    server __PRODUCT_HOST__:3002;
}

server {
    listen 8081;
    listen [::]:8081;
    server_name localhost;
    client_max_body_size 10m;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    location /health {
        default_type application/json;
        return 200 '{"status":"ok"}';
    }

    location ~ ^/api/makeline/order/(?<id>\w+) {
        proxy_pass http://makeline_service/order/$id;
        proxy_http_version 1.1;
    }

    location /api/makeline/order {
        proxy_pass http://makeline_service/order;
        proxy_http_version 1.1;
    }

    location /api/makeline/order/fetch {
        proxy_pass http://makeline_service/order/fetch;
        proxy_http_version 1.1;
    }

    location /api/order {
        rewrite ^/api/order$ / break;
        rewrite ^/api/order(/.*)$ $1 break;
        proxy_pass http://order_service;
        proxy_http_version 1.1;
    }

    location /api/products/ {
        proxy_pass http://product_service/;
        proxy_http_version 1.1;
    }

    location /api/products {
        rewrite ^/api/products$ / break;
        rewrite ^/api/products(/.*)$ $1 break;
        proxy_pass http://product_service;
        proxy_http_version 1.1;
    }

    location ~ ^/api/product/(?<id>\w+) {
        proxy_pass http://product_service/$id;
        proxy_http_version 1.1;
    }

    location /api/product {
        rewrite ^/api/product$ / break;
        rewrite ^/api/product(/.*)$ $1 break;
        proxy_pass http://product_service;
        proxy_http_version 1.1;
    }

    location /api/product/ {
        proxy_pass http://product_service/;
        proxy_http_version 1.1;
    }
}
''', '__MAKELINE_HOST__', makelineServiceContainer.properties.hosts.makelineService), '__ORDER_HOST__', orderServiceContainer.properties.hosts.orderService), '__PRODUCT_HOST__', productServiceContainer.properties.hosts.productService)
      }
    }
    kind: 'generic'
  }
}

resource storeFrontNginxConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'store-front-nginx-config'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-front/nginx.conf#L1'
    data: {
      'default.conf': {
        #disable-next-line use-secure-value-for-secure-inputs
        value: replace(replace('''
upstream order_service {
    server __ORDER_HOST__:3000;
}

upstream product_service {
    server __PRODUCT_HOST__:3002;
}

server {
    listen 8080;
    listen [::]:8080;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    location /health {
        default_type application/json;
        return 200 '{"status":"ok"}';
    }

    location /api/orders {
        rewrite ^/api/orders$ / break;
        rewrite ^/api/orders(/.*)$ $1 break;
        proxy_pass http://order_service;
        proxy_http_version 1.1;
    }

    location /api/products {
        rewrite ^/api/products$ / break;
        rewrite ^/api/products(/.*)$ $1 break;
        proxy_pass http://product_service;
        proxy_http_version 1.1;
    }
}
''', '__ORDER_HOST__', orderServiceContainer.properties.hosts.orderService), '__PRODUCT_HOST__', productServiceContainer.properties.hosts.productService)
      }
    }
    kind: 'generic'
  }
}

resource aiServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'ai-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/ai-service/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/ai-service?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource makelineServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'makeline-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/makeline-service/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/makeline-service?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource orderServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/order-service/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/order-service?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource productServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'product-service-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/product-service/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/product-service?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeAdminImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-admin-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-admin/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/store-admin?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource storeFrontImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'store-front-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-front/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/store-front?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualCustomerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-customer-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/virtual-customer/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/virtual-customer?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource virtualWorkerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'virtual-worker-image'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/virtual-worker/Dockerfile#L1'
    tag: 'f9ddce8'
    build: {
      source: 'git::https://github.com/ryanwaite/aks-store-demo.git//src/virtual-worker?ref=f9ddce8ea89416a5a3500ead947e883525ff892d'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource aiServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'ai-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/ai-service/main.py#L17'
    replicas: 1
    containers: {
      aiService: {
        image: aiServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 5001
          }
        }
        env: {
          AZURE_OPENAI_API_KEY: {
            valueFrom: {
              secretKeyRef: {
                secretName: aiServiceCredentials.name
                key: 'AZURE_OPENAI_API_KEY'
              }
            }
          }
          AZURE_OPENAI_API_VERSION: {
            value: '2024-12-01-preview'
          }
          AZURE_OPENAI_DEPLOYMENT_NAME: {
            value: aiDeploymentName
          }
          AZURE_OPENAI_ENDPOINT: {
            value: aiEndpoint
          }
          AZURE_OPENAI_IMAGE_API_VERSION: {
            value: '2025-04-01-preview'
          }
          AZURE_OPENAI_IMAGE_DEPLOYMENT_NAME: {
            value: aiImageDeploymentName
          }
          AZURE_OPENAI_IMAGE_ENDPOINT: {
            value: aiImageEndpoint
          }
          USE_AZURE_AD: {
            value: 'False'
          }
          USE_AZURE_OPENAI: {
            value: 'True'
          }
        }
      }
    }
  }
}

resource makelineServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'makeline-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/makeline-service/main.go#L21'
    replicas: 1
    containers: {
      makelineService: {
        image: makelineServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3001
          }
        }
        env: {
          ORDER_DB_COLLECTION_NAME: {
            value: 'orders'
          }
          ORDER_DB_NAME: {
            value: 'orderdb'
          }
          ORDER_DB_URI: {
            valueFrom: {
              secretKeyRef: {
                secretName: mongoDb.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: rabbitCredentials.name
                key: 'password'
              }
            }
          }
          ORDER_QUEUE_URI: {
            value: 'amqp://${rabbitMQ.properties.host}:${rabbitMQ.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
      }
    }
  }
}

resource orderServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/order-service/app.js#L6'
    replicas: 1
    containers: {
      orderService: {
        image: orderServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          FASTIFY_ADDRESS: {
            value: '0.0.0.0'
          }
          ORDER_QUEUE_HOSTNAME: {
            value: rabbitMQ.properties.host
          }
          ORDER_QUEUE_NAME: {
            value: 'orders'
          }
          ORDER_QUEUE_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: rabbitCredentials.name
                key: 'password'
              }
            }
          }
          ORDER_QUEUE_PORT: {
            value: '${rabbitMQ.properties.port}'
          }
          ORDER_QUEUE_USERNAME: {
            value: 'username'
          }
        }
      }
    }
  }
}

resource productServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'product-service'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/product-service/src/main.rs#L5'
    replicas: 1
    containers: {
      productService: {
        image: productServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3002
          }
        }
        env: {
          AI_SERVICE_URL: {
            value: 'http://${aiServiceContainer.properties.hosts.aiService}:5001'
          }
        }
      }
    }
    connections: {
      aiService: {
        source: aiServiceContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource storeAdminContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-admin'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-admin/nginx.conf#L1'
    replicas: 1
    containers: {
      storeAdmin: {
        image: storeAdminImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        volumeMounts: [
          {
            volumeName: 'nginxConfig'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      nginxConfig: {
        secretName: storeAdminNginxConfig.name
      }
    }
    connections: {
      makelineService: {
        source: makelineServiceContainer.id
        disableDefaultEnvVars: true
      }
      orderService: {
        source: orderServiceContainer.id
        disableDefaultEnvVars: true
      }
      productService: {
        source: productServiceContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource storeFrontContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'store-front'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/store-front/nginx.conf#L1'
    replicas: 1
    containers: {
      storeFront: {
        image: storeFrontImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        volumeMounts: [
          {
            volumeName: 'nginxConfig'
            mountPath: '/etc/nginx/conf.d'
          }
        ]
      }
    }
    volumes: {
      nginxConfig: {
        secretName: storeFrontNginxConfig.name
      }
    }
    connections: {
      orderService: {
        source: orderServiceContainer.id
        disableDefaultEnvVars: true
      }
      productService: {
        source: productServiceContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource virtualCustomerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-customer'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/virtual-customer/src/main.rs#L7'
    replicas: 1
    containers: {
      virtualCustomer: {
        image: virtualCustomerImage.properties.imageReference
        env: {
          ORDERS_PER_HOUR: {
            value: '20'
          }
          ORDER_SERVICE_URL: {
            value: 'http://${orderServiceContainer.properties.hosts.orderService}:3000/'
          }
        }
      }
    }
  }
}

resource virtualWorkerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'virtual-worker'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/src/virtual-worker/src/main.rs#L6'
    replicas: 1
    containers: {
      virtualWorker: {
        image: virtualWorkerImage.properties.imageReference
        env: {
          MAKELINE_SERVICE_URL: {
            value: 'http://${makelineServiceContainer.properties.hosts.makelineService}:3001'
          }
          ORDERS_PER_HOUR: {
            value: '10'
          }
        }
      }
    }
  }
}

resource storeAdminRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'store-admin-route'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/charts/aks-store-demo/templates/store-admin.yaml#L53'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: storeAdminContainer.id
          containerName: 'storeAdmin'
          containerPort: 8081
        }
      }
    ]
  }
}

resource storeFrontRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'store-front-route'
  properties: {
    environment: environment
    application: aksStoreDemoApp.id
    codeReference: 'https://github.com/ryanwaite/aks-store-demo/blob/ryanwaite-stunning-chainsaw/charts/aks-store-demo/templates/store-front.yaml#L53'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: storeFrontContainer.id
          containerName: 'storeFront'
          containerPort: 8080
        }
      }
    ]
  }
}
