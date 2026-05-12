Poniżej dostajesz **gotowy plik `.md`**, który możesz wkleić do repo lub używać jako instrukcji.  
Nie wymaga on żadnych dodatkowych narzędzi poza Dockerem i AWS CLI.

---

# 🚀 MiniStack + API Gateway + WAF — Instrukcja uruchomienia  
**Plik: `ministack-waf-apigw-setup.md`**

## Spis treści
1. Wymagania  
2. Uruchomienie MiniStack  
3. Tworzenie WebACL (WAFv2)  
4. Tworzenie API Gateway HTTP API  
5. Integracja API Gateway → Twoja aplikacja  
6. Podpięcie WAF do API Gateway  
7. Testowanie ruchu przez WAF  
8. Diagram przepływu  
9. Troubleshooting

---

## 1. Wymagania

- Docker  
- AWS CLI (dowolna wersja 2.x)  
- Twoja aplikacja backendowa działająca lokalnie (np. `http://localhost:5000`)  

Uwaga: MiniStack działa na porcie `4566` (jak LocalStack).

---

## 2. Uruchomienie MiniStack

```bash
docker run --rm -it \
  -p 4566:4566 \
  ministackorg/ministack
```

Po uruchomieniu wszystkie usługi AWS są dostępne pod:

```
http://localhost:4566
```

---

## 3. Tworzenie WebACL (WAFv2)

Tworzymy pusty WebACL, który domyślnie przepuszcza ruch:

```bash
aws wafv2 create-web-acl \
  --endpoint-url http://localhost:4566 \
  --name test-acl \
  --scope REGIONAL \
  --default-action Allow={} \
  --rules '[]' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=TestACL
```

Zapisz wartość `ARN` z odpowiedzi — będzie potrzebna później.

---

## 4. Tworzenie API Gateway (HTTP API – v2)

```bash
aws apigatewayv2 create-api \
  --endpoint-url http://localhost:4566 \
  --name test-api \
  --protocol-type HTTP
```

Zapisz `ApiId` z odpowiedzi.

---

## 5. Integracja API Gateway → Twoja aplikacja

Załóżmy, że Twoja aplikacja działa na:

```
http://host.docker.internal:5000
```

> `host.docker.internal` działa w Dockerze i wskazuje na hosta.

### 5.1 Tworzenie integracji

```bash
aws apigatewayv2 create-integration \
  --endpoint-url http://localhost:4566 \
  --api-id <ApiId> \
  --integration-type HTTP_PROXY \
  --integration-uri http://host.docker.internal:5000
```

Zapisz `IntegrationId`.

### 5.2 Tworzenie route

```bash
aws apigatewayv2 create-route \
  --endpoint-url http://localhost:4566 \
  --api-id <ApiId> \
  --route-key "ANY /{proxy+}" \
  --target integrations/<IntegrationId>
```

### 5.3 Tworzenie stage

```bash
aws apigatewayv2 create-stage \
  --endpoint-url http://localhost:4566 \
  --api-id <ApiId> \
  --stage-name dev
```

---

## 6. Podpięcie WAF do API Gateway

WAF musi być podpięty do konkretnego stage API Gateway.

Format ARN w MiniStack:

```
arn:aws:apigateway:us-east-1:000000000000:/apis/<ApiId>/stages/dev
```

### Komenda:

```bash
aws wafv2 associate-web-acl \
  --endpoint-url http://localhost:4566 \
  --web-acl-arn <WebACLArn> \
  --resource-arn arn:aws:apigateway:us-east-1:000000000000:/apis/<ApiId>/stages/dev
```

---

## 7. Testowanie ruchu przez WAF

MiniStack wystawia API Gateway pod:

```
http://localhost/_aws/execute-api/<ApiId>/dev/<path>
```

Przykład:

```bash
curl http://localhost/_aws/execute-api/<ApiId>/dev/hello
```

Jeśli wszystko działa:

- żądanie trafia do API Gateway,
- API Gateway odpala WAF,
- WAF przepuszcza lub blokuje,
- Twoja aplikacja dostaje request.

---

## 8. Diagram przepływu

```
curl → API Gateway → WAF → HTTP_PROXY → Twoja aplikacja
```

---

## 9. Troubleshooting

### ❗ 404 / brak odpowiedzi
Sprawdź, czy Twoja aplikacja działa na `http://host.docker.internal:5000`.

### ❗ WAF nie blokuje ruchu
Dodaj regułę do WebACL:

```bash
aws wafv2 update-web-acl ...
```

### ❗ API Gateway nie widzi integracji
Sprawdź `IntegrationId` i `route-key`.

---

Jeśli chcesz, mogę przygotować **drugą wersję instrukcji**:

- Terraform  
- CDK  
- Docker Compose  
- Makefile  
- Gotowy skrypt `setup.sh`  

Powiedz tylko, w jakiej formie chcesz to mieć.