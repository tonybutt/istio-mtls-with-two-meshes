kind create cluster --name ingress
kind create cluster --name egress

istioctl install \
  --context kind-ingress \
  --set profile=minimal \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set "components.ingressGateways[0].name=istio-ingressgateway" \
  --set "components.ingressGateways[0].enabled=true" \
  -y

istioctl install \
  --context kind-egress \
  --set profile=minimal \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set "components.egressGateways[0].name=istio-egressgateway" \
  --set "components.egressGateways[0].enabled=true" \
  -y

kubectl --context kind-ingress apply -k manifests/ingress
kubectl --context kind-egress -k manifests/egress

ipaddress=$(kubectl --context kind-ingress \
  -n istio-system get svc istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

kubectl --context kind-egress get configmap coredns -n kube-system -o json |
  jq --arg ip "$ipaddress" '.data.Corefile |= sub("(?m)^kubernetes"; "hosts {\n  $ip httpbin.example.com\n  fallthrough\n}\nkubernetes")' |
  kubectl --context kind-egress apply -f -

mkdir certs
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=example Inc./CN=example.com' \
  -keyout certs/example.com.key \
  -out certs/example.com.crt

openssl req -out certs/client.example.com.csr -nodes -newkey rsa:2048 \
  -keyout certs/client.example.com.key \
  -subj "/CN=client.example.com/O=client organization"

openssl x509 -req -sha256 -days 365 \
  -CA certs/example.com.crt \
  -CAkey certs/example.com.key \
  -set_serial 1 \
  -in certs/client.example.com.csr \
  -out certs/client.example.com.crt

openssl req -out certs/httpbin.example.com.csr -newkey rsa:2048 -nodes \
  -keyout certs/httpbin.example.com.key \
  -subj "/CN=httpbin.example.com/O=httpbin organization"

openssl x509 -req -sha256 -days 365 \
  -CA example.com.crt \
  -CAkey example.com.key \
  -set_serial 1 \
  -in httpbin.example.com.csr \
  -out httpbin.example.com.crt

kubectl create secret \
  --context kind-egress \
  -n istio-system generic client-credential \
  --from-file=tls.key=client.example.com.key \
  --from-file=tls.crt=client.example.com.crt \
  --from-file=ca.crt=example.com.crt

kubectl --context kind-ingress \
  create secret tls httpbin-credential \
  -n istio-system \
  --key=httpbin.example.com.key \
  --cert=httpbin.example.com.crt
